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

#[test(should_fail_with = "Not incrementor or admin")]
unconstrained fn increment_fails_if_not_admin() {
    let mut env = aztec::test::helpers::test_environment::TestEnvironment::new();

    let admin = env.create_light_account();
    let not_admin = env.create_light_account();

    let initializer_call_interface = Counter::interface().constructor(admin);
    let counter_deployer = env.deploy("@counter_contract/Counter");
    let contract_address =
        counter_deployer.with_public_initializer(admin, initializer_call_interface);

    env.call_private(not_admin, Counter::at(contract_address).increment());
}

#[test]
unconstrained fn add_incrementor_success() {
    let (env, contract_address, admin, user) = utils::setup_contract(false);

    // Admin adds user as incrementor
    env.call_private(admin, Counter::at(contract_address).add_incrementor(user));

    // Verify the incrementor can now increment
    env.call_private(user, Counter::at(contract_address).increment());
    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);
}

#[test(should_fail_with = "Not admin")]
unconstrained fn add_incrementor_fails_if_not_admin() {
    let (env, contract_address, _, user) = utils::setup_contract(false);

    // Non-admin tries to add an incrementor
    env.call_private(user, Counter::at(contract_address).add_incrementor(user));
}

#[test]
unconstrained fn incrementor_can_increment_after_being_added() {
    let (env, contract_address, admin, user) = utils::setup_contract(false);

    // Admin adds user as incrementor
    env.call_private(admin, Counter::at(contract_address).add_incrementor(user));

    // Incrementor calls increment
    env.call_private(user, Counter::at(contract_address).increment());

    // Verify counter increased
    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);
}

#[test]
unconstrained fn incrementor_can_increment_multiple_times() {
    let (env, contract_address, admin, user) = utils::setup_contract(false);

    // Admin adds user as incrementor
    env.call_private(admin, Counter::at(contract_address).add_incrementor(user));

    // Incrementor calls increment twice
    env.call_private(user, Counter::at(contract_address).increment());
    env.call_private(user, Counter::at(contract_address).increment());

    // Verify counter increased
    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 2);
}

#[test]
unconstrained fn add_multiple_incrementors_success() {
    let (env, contract_address, admin, user1) = utils::setup_contract(false);

    let user2 = env.create_light_account();

    // Admin adds first incrementor
    env.call_private(admin, Counter::at(contract_address).add_incrementor(user1));

    // Admin adds second incrementor
    env.call_private(admin, Counter::at(contract_address).add_incrementor(user2));

    // Verify both incrementors can increment
    env.call_private(user1, Counter::at(contract_address).increment());
    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);

    env.call_private(user2, Counter::at(contract_address).increment());
    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 2);
}

#[test]
unconstrained fn remove_incrementor_succeeds() {
    let (env, contract_address, admin, user) = utils::setup_contract(false);

    // Admin adds user as incrementor
    env.call_private(admin, Counter::at(contract_address).add_incrementor(user));

    // admin removes the incrementor - should succeed without error
    env.call_private(admin, Counter::at(contract_address).remove_incrementor(user));
}

#[test(should_fail_with = "Caller is not admin")]
unconstrained fn remove_incrementor_fails_if_not_admin() {
    let (env, contract_address, admin, user1) = utils::setup_contract(false);

    let user2 = env.create_light_account();

    // Admin adds user1 as incrementor
    env.call_private(admin, Counter::at(contract_address).add_incrementor(user1));

    // user2 (non-admin) tries to remove user1
    env.call_private(user2, Counter::at(contract_address).remove_incrementor(user1));
}
