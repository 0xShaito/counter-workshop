use crate::{Counter, test::utils};

#[test]
unconstrained fn increment_success() {
    let (env, contract_address, admin, _) = utils::setup_contract(false);

    env.call_private(admin, Counter::at(contract_address).increment());

    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);
}

#[test]
unconstrained fn does_it_fail_to_call_the_initializer() {
    let mut env = aztec::test::helpers::test_environment::TestEnvironment::new();

    let admin = env.create_light_account();

    let initializer_call_interface = Counter::interface().constructor(admin);
    let counter_deployer = env.deploy("@counter_contract/Counter");
    let contract_address =
        counter_deployer.with_public_initializer(admin, initializer_call_interface);

    env.call_private(admin, Counter::at(contract_address).increment());

    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);
}
