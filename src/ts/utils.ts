import { Wallet } from "@aztec/aztec.js/wallet";
import {
  CounterContract,
  CounterContractArtifact,
} from "../artifacts/Counter.js";
import { AztecAddress } from "@aztec/stdlib/aztec-address";
import { Contract } from "@aztec/aztec.js/contracts";

/**
 * Deploys the Counter contract.
 * @param deployer - The wallet to deploy the contract with.
 * @param admin - The address of the admin of the contract.
 * @returns A deployed contract instance.
 */
export async function deployCounter(
  deployer: Wallet,
  admin: AztecAddress,
): Promise<CounterContract> {
  const deployerAddress = (await deployer.getAccounts())[0]!.item;
  const deployMethod = Contract.deploy(
    deployer,
    CounterContractArtifact,
    [admin],
    "constructor", // not actually needed since it's the default constructor
  );
  const tx = deployMethod.send({
    from: deployerAddress,
  });
  const contract = await tx.deployed();
  return contract as CounterContract;
}
