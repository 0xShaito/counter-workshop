import "dotenv/config";
import { Command } from "commander";
import { PublicKeys } from "@aztec/aztec.js/keys";
import {
  getContractInstanceFromInstantiationParams,
  DeployMethod,
  Contract,
  DefaultWaitOpts,
  DeployOptions,
  ContractBase,
  WaitOpts,
  type InteractionFeeOptions,
} from "@aztec/aztec.js/contracts";
import { AztecAddress } from "@aztec/aztec.js/addresses";
import { Fr } from "@aztec/aztec.js/fields";
import { SponsoredFeePaymentMethod } from "@aztec/aztec.js/fee";
import { AccountWithSecretKey, Account } from "@aztec/aztec.js/account";
import {
  AccountManager,
  BaseWallet,
  type Wallet,
} from "@aztec/aztec.js/wallet";
import { createAztecNodeClient, type AztecNode } from "@aztec/aztec.js/node";
import { createLogger } from "@aztec/foundation/log";
import { sleep } from "@aztec/foundation/sleep";

import { SingleKeyAccountContract } from "@aztec/accounts/single_key";
import { deriveSigningKey } from "@aztec/stdlib/keys";
import { SponsoredFPCContract } from "@aztec/noir-contracts.js/SponsoredFPC";
import { SPONSORED_FPC_SALT } from "@aztec/constants";
import { poseidon2Hash } from "@aztec/foundation/crypto";
import {
  CounterContract,
  CounterContractArtifact,
} from "../src/artifacts/Counter.js";
import { createStore } from "@aztec/kv-store/lmdb-v2";
import { createPXE, getPXEConfig } from "@aztec/pxe/server";
import type { PXE, PXEConfig, PXECreationOptions } from "@aztec/pxe/server";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const packageJson = JSON.parse(
  readFileSync(join(__dirname, "../package.json"), "utf-8"),
);

const amt = (n: number = 1, decimals: number = 1) => {
  return BigInt(n * 10 ** decimals);
};

const logger = createLogger("aztec:deploy");

// CLI options interface
interface CLIOptions {
  nodeUrl?: string;
  deployerSecret?: string;
}

const defaultWaitOptions: WaitOpts = {
  timeout: 600,
};

export async function setupPXE(node: AztecNode): Promise<PXE> {
  const { PXE_VERSION = "2" } = process.env;
  const pxeVersion = parseInt(PXE_VERSION);

  const config = {
    ...getPXEConfig(),
    proverEnabled: false,
  };
  const options: PXECreationOptions = {
    store: await createStore("deployer-store", pxeVersion, {
      dataDirectory: "deployer-store/",
      dataStoreMapSizeKb: 1e6,
    }),
  };
  //   await options.store!.delete();
  const pxe = await createPXE(node, config, options);
  logger.info("Connected to PXE");

  try {
    const nodeInfo = await node.getNodeInfo();
    logger.info(`Connected to Aztec node version: ${nodeInfo.nodeVersion}`);

    return pxe;
  } catch (error) {
    logger.error("Failed to connect to PXE:", error);
    throw error;
  }
}

class MinimalWallet extends BaseWallet {
  private readonly addressToAccount = new Map<string, AccountWithSecretKey>();

  constructor(pxe: PXE, aztecNode: AztecNode) {
    super(pxe as unknown as any, aztecNode);
  }

  public addAccount(account: AccountWithSecretKey) {
    this.addressToAccount.set(account.getAddress().toString(), account);
  }

  protected async getAccountFromAddress(
    address: AztecAddress,
  ): Promise<Account> {
    const acc = this.addressToAccount.get(address.toString());
    if (!acc)
      throw new Error(
        `Account not found in wallet for address: ${address.toString()}`,
      );
    return acc;
  }

  async getAccounts(): Promise<{ alias: string; item: AztecAddress }[]> {
    return Array.from(this.addressToAccount.values()).map((acc) => ({
      alias: "",
      item: acc.getAddress(),
    }));
  }
}

export async function createAccount(
  pxe: PXE,
  node: AztecNode,
  secret: Fr,
): Promise<{ wallet: Wallet; account: AccountWithSecretKey }> {
  logger.info("Creating account...");

  const wallet = new MinimalWallet(pxe, node);
  const signingKey = deriveSigningKey(secret);
  const accountContract = new SingleKeyAccountContract(signingKey);
  const manager = await AccountManager.create(
    wallet,
    secret,
    accountContract,
    Fr.ZERO,
  );
  const account = await manager.getAccount();
  const instance = manager.getInstance();
  const artifact = await manager.getAccountContract().getContractArtifact();
  await wallet.registerContract(instance, artifact, manager.getSecretKey());
  wallet.addAccount(account);

  logger.info(`Account created: ${account.getAddress().toString()}`);
  return { wallet, account };
}

export async function createSponsoredFeeOptions(
  pxe: PXE,
): Promise<InteractionFeeOptions> {
  logger.info("Setting up sponsored fee options...");

  const sponsoredFPCInstance = await getContractInstanceFromInstantiationParams(
    SponsoredFPCContract.artifact,
    {
      salt: new Fr(SPONSORED_FPC_SALT),
    },
  );

  try {
    await pxe.registerContract({
      instance: sponsoredFPCInstance,
      artifact: SponsoredFPCContract.artifact,
    });
    logger.info(
      `Registered SponsoredFPC at: ${sponsoredFPCInstance.address.toString()}`,
    );
  } catch (error) {
    logger.debug("SponsoredFPC already registered");
  }

  const paymentMethod = new SponsoredFeePaymentMethod(
    sponsoredFPCInstance.address,
  );

  return {
    paymentMethod,
  };
}

export async function deployCounter(
  deployer: Wallet,
  owner: AztecAddress,
  options: DeployOptions,
): Promise<CounterContract> {
  logger.info(`Deploying Counter contract for owner: ${owner.toString()}`);
  const deployMethod = await Contract.deploy(
    deployer,
    CounterContractArtifact,
    [owner],
    "constructor", // not actually needed since it's the default constructor
  );
  // FIXME: awful
  options = {
    ...options,
    contractAddressSalt: options.contractAddressSalt || Fr.fromString("1337"),
  };
  let contract, transactionFee, txHash;
  const result = await deployMethod
    .send({
      ...options,
    })
    .wait({ timeout: 120 });
  contract = result.contract;
  transactionFee = result.transactionFee;
  txHash = result.txHash;

  const counterContract = await CounterContract.at(contract.address, deployer);
  logger.info(`Counter deployed at: ${contract.address.toString()}`);

  return counterContract;
}

export async function deployToTestnet(
  options: CLIOptions,
): Promise<{ counter: CounterContract; deployer: AztecAddress }> {
  logger.info("Deploying to Aztec Testnet...");

  try {
    // Set Node and PXE URLs from options or environment
    const nodeUrl =
      options.nodeUrl ||
      process.env.AZTEC_NODE_URL ||
      "https://devnet.aztec-labs.com";
    // Get deployer secret
    const deployerSecretStr =
      options.deployerSecret || process.env.DEPLOYER_SECRET;
    if (!deployerSecretStr) {
      throw new Error(
        "Deployer secret is required (use --deployer-secret or DEPLOYER_SECRET env var)",
      );
    }
    const deployerSecret = await poseidon2Hash([
      Fr.fromBufferReduce(Buffer.from(deployerSecretStr, "utf8")),
    ]);

    const node = createAztecNodeClient(nodeUrl);
    const pxe = await setupPXE(node);
    const deployer = await createAccount(pxe, node, deployerSecret);
    console.info(`The deployer account is ${deployer.account.getAddress()}`);
    const sponsoredFeeOptions = await createSponsoredFeeOptions(pxe);

    const deployOptions: DeployOptions = {
      from: deployer.account.getAddress(),
      fee: sponsoredFeeOptions,
      contractAddressSalt: Fr.random(),
    };

    logger.info(
      `Deploying with account: ${deployer.account.getAddress().toString()}`,
    );

    const counter = await deployCounter(
      deployer.wallet,
      deployer.account.getAddress(),
      deployOptions,
    );

    logger.info("Deployment completed successfully!");
    return {
      counter,
      deployer: deployer.account.getAddress(),
    };
  } catch (error) {
    logger.error("Testnet deployment failed:", error);
    throw error;
  }
}

// CLI setup
const program = new Command();

program
  .name("deploy")
  .description("Deploy Aztec Standards contracts to testnet")
  .version(packageJson.version)
  .option("--node-url <url>", "Aztec Node URL")
  .option(
    "--deployer-secret <secret>",
    "Deployer secret (or use DEPLOYER_SECRET env var)",
  )
  .action(async (options) => {
    try {
      console.log("options", options);
      const { counter, deployer } = await deployToTestnet(options);
      console.info(`Counter deployed at: ${counter.address.toString()}`);
      console.info(
        `https://devnet.aztecscan.xyz/contracts/instances/${counter.address.toString()}`,
      );
      console.info(`Deployer account: ${deployer.toString()}`);
      process.exit(0);
    } catch (error) {
      logger.error("Deployment failed:", error);
      process.exit(1);
    }
  });

// Parse arguments when run directly
if (import.meta.url === `file://${process.argv[1]}`) {
  program.parse(process.argv);
}
