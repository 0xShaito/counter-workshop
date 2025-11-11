use crate::{Counter, test::utils};

#[test]
unconstrained fn increment_success() {
    let (env, contract_address, owner, _) = utils::setup_contract(false);

    env.call_private(owner, Counter::at(contract_address).increment());

    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);
}

#[test]
unconstrained fn does_it_fail_to_call_the_initializer() {
    let mut env = aztec::test::helpers::test_environment::TestEnvironment::new();

    let owner = env.create_light_account();

    let initializer_call_interface = Counter::interface().constructor(owner);
    let counter_deployer = env.deploy("@counter_contract/Counter");
    let contract_address =
        counter_deployer.with_public_initializer(owner, initializer_call_interface);

    env.call_private(owner, Counter::at(contract_address).increment());

    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);
}

#[test(should_fail_with = "Caller is not owner or incrementor")]
unconstrained fn increment_fails_if_not_owner() {
    let mut env = aztec::test::helpers::test_environment::TestEnvironment::new();

    let owner = env.create_light_account();
    let not_owner = env.create_light_account();

    let initializer_call_interface = Counter::interface().constructor(owner);
    let counter_deployer = env.deploy("@counter_contract/Counter");
    let contract_address =
        counter_deployer.with_public_initializer(owner, initializer_call_interface);

    env.call_private(not_owner, Counter::at(contract_address).increment());
}

#[test]
unconstrained fn add_incrementor_success() {
    let (env, contract_address, owner, user) = utils::setup_contract(false);

    // Owner adds user as incrementor
    env.call_private(owner, Counter::at(contract_address).add_incrementor(user));

    // Verify the incrementor can now increment
    env.call_private(user, Counter::at(contract_address).increment());
    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);
}

#[test(should_fail_with = "Caller is not owner")]
unconstrained fn add_incrementor_fails_if_not_owner() {
    let (env, contract_address, _, user) = utils::setup_contract(false);

    // Non-owner tries to add an incrementor
    env.call_private(user, Counter::at(contract_address).add_incrementor(user));
}

#[test(should_fail_with = "Incrementor already exists")]
unconstrained fn add_incrementor_fails_if_already_exists() {
    let (env, contract_address, owner, user) = utils::setup_contract(false);

    // Owner adds user as incrementor
    env.call_private(owner, Counter::at(contract_address).add_incrementor(user));

    // Owner tries to add the same user again
    env.call_private(owner, Counter::at(contract_address).add_incrementor(user));
}

#[test]
unconstrained fn incrementor_can_increment_after_being_added() {
    let (env, contract_address, owner, user) = utils::setup_contract(false);

    // Owner adds user as incrementor
    env.call_private(owner, Counter::at(contract_address).add_incrementor(user));

    // Incrementor calls increment
    env.call_private(user, Counter::at(contract_address).increment());

    // Verify counter increased
    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);
}

#[test]
unconstrained fn add_multiple_incrementors_success() {
    let (env, contract_address, owner, user1) = utils::setup_contract(false);

    let user2 = env.create_light_account();

    // Owner adds first incrementor
    env.call_private(owner, Counter::at(contract_address).add_incrementor(user1));

    // Owner adds second incrementor
    env.call_private(owner, Counter::at(contract_address).add_incrementor(user2));

    // Verify both incrementors can increment
    env.call_private(user1, Counter::at(contract_address).increment());
    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);

    env.call_private(user2, Counter::at(contract_address).increment());
    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 2);
}
