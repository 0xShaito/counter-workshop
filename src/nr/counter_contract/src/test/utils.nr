use crate::Counter;
use aztec::{
    protocol_types::address::AztecAddress, test::helpers::test_environment::TestEnvironment,
};

pub unconstrained fn setup_contract(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
    let mut env = TestEnvironment::new();
    let (admin, user) = if with_account_contracts {
        let admin = env.create_contract_account();
        let user = env.create_contract_account();
        (admin, user)
    } else {
        let admin = env.create_light_account();
        let user = env.create_light_account();
        (admin, user)
    };

    let contract_address = deploy_contract(&mut env, admin);

    (&mut env, contract_address, admin, user)
}

pub unconstrained fn deploy_contract(
    env: &mut TestEnvironment,
    admin: AztecAddress,
) -> AztecAddress {
    let initializer_call_interface = Counter::interface().constructor(admin);
    let contract_address =
        env.deploy("Counter").with_public_initializer(admin, initializer_call_interface);

    contract_address
}
