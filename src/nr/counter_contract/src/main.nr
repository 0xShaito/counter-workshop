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
        incrementors: PrivateSet<IncrementorNote, Context>,
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

    /// @dev Allows the admin to add an incrementor
    /// @param incrementor The address of the incrementor to add
    #[external("private")]
    fn add_incrementor(incrementor: AztecAddress) {
        let sender = context.msg_sender().unwrap();
        let admin = storage.owner.read();

        assert_eq(sender, admin, "Not admin");

        let incrementor_note = IncrementorNote::new(incrementor);
        // Does not check if the incrementor already exists
        let note_emission = storage.incrementors.insert(incrementor_note);

        note_emission.emit(incrementor, MessageDelivery.CONSTRAINED_ONCHAIN);
        note_emission.emit(admin, MessageDelivery.CONSTRAINED_ONCHAIN);
    }

    /// @dev Allows the admin to remove an incrementor
    /// @param incrementor The address of the incrementor to remove
    #[external("private")]
    fn remove_incrementor(incrementor: AztecAddress) {
        let sender = context.msg_sender().unwrap();
        assert_eq(sender, storage.admin.read(), "Caller is not admin");

        let options = NoteGetterOptions::new()
            .select(IncrementorNote::properties().owner, Comparator.EQ, incrementor)
            .set_limit(1);
        let _ = storage.incrementors.pop_notes(options);
    }

    /// @dev Increments the counter
    #[external("private")]
    fn increment() {
        let sender = context.msg_sender().unwrap();
        // We can access the admin because it is public immutable
        let admin = storage.owner.read();

        if (admin != sender) {
            // Check if sender has an incrementor note
            let options = NoteGetterOptions::new()
                .select(IncrementorNote::properties().owner, Comparator.EQ, sender)
                .set_limit(1);
            let notes = storage.incrementors.get_notes(options);
            assert(notes.len() > 0, "Not incrementor or admin");
        }

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
