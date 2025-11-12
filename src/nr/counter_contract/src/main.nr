use aztec::macros::aztec;
pub mod test;
pub mod types;

#[aztec]
pub contract Counter {
    // aztec library imports
    use aztec::{
        macros::{functions::{external, initializer, internal, view}, storage::storage},
        messages::message_delivery::MessageDelivery,
        note::{note_getter_options::NoteGetterOptions, note_interface::NoteProperties},
        protocol_types::address::AztecAddress,
        state_vars::{PrivateSet, PublicImmutable, PublicMutable},
        utils::comparison::Comparator,
    };

    // import incrementor note
    // use crate::types::incrementor_note::IncrementorNote;

    // @param admin The address of the admin
    // @param counter A numerical value
    // @param incrementors A set of incrementor notes
    #[storage]
    struct Storage<Context> {
        admin: PublicImmutable<AztecAddress, Context>,
        counter: PublicMutable<u128, Context>,
    }

    /// @dev Initialize the contract
    /// @param admin The address of the admin
    #[external("public")]
    #[initializer]
    fn constructor(admin: AztecAddress) {
        storage.admin.initialize(admin);
    }

    /// @dev Retrieves the admin of the contract
    /// @return The admin of the contract
    #[external("public")]
    fn get_admin() -> AztecAddress {
        storage.admin.read()
    }

    /// @dev Increments the counter
    #[external("private")]
    fn increment() {
        Counter::at(context.this_address()).increment_internal().enqueue(&mut context);
    }

    /// @dev Retrieves the counter value
    /// @return The current counter value
    #[external("public")]
    #[view]
    fn get_counter() -> u128 {
        storage.counter.read()
    }

    /// @dev Increments the counter
    #[external("public")]
    #[internal]
    fn increment_internal() {
        let current_value = storage.counter.read();
        storage.counter.write(current_value + 1);
    }
}
