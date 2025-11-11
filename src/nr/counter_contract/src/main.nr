use aztec::macros::aztec;
pub mod test;
pub mod types;

#[aztec]
pub contract Counter {
    // aztec library imports
    use aztec::{
        macros::{functions::{external, initializer, internal, view}, storage::storage},
        note::note_getter_options::NoteGetterOptions,
        note::note_interface::NoteProperties,
        messages::message_delivery::MessageDelivery,
        protocol_types::address::AztecAddress,
        state_vars::{PublicImmutable, PublicMutable, PrivateSet},
        utils::comparison::Comparator,
    };

    // import incrementor note
    use crate::types::incrementor_note::IncrementorNote;

    // @param owner The address of the owner
    // @param counter A numerical value
    #[storage]
    struct Storage<Context> {
        owner: PublicImmutable<AztecAddress, Context>,
        counter: PublicMutable<u128, Context>,
        incrementors: PrivateSet<IncrementorNote, Context>
    }

    /// @dev Initialize the contract
    /// @param owner The address of the owner
    #[external("public")]
    #[initializer]
    fn constructor(owner: AztecAddress) {
        storage.owner.initialize(owner);
    }

    /// @dev Retrieves the owner of the contract
    /// @return The owner of the contract
    #[external("public")]
    fn get_owner() -> AztecAddress {
        storage.owner.read()
    }

    /// @dev Allows the owner to add an incrementor
    #[external("private")]
    fn add_incrementor(incrementor: AztecAddress) {
        let sender = context.msg_sender();
        assert(sender.is_some(), "Sender is not set");
        assert_eq(sender.unwrap_unchecked(), storage.owner.read(), "Caller is not owner");

        // Check if incrementor already exists
        let options = NoteGetterOptions::new()
            .select(IncrementorNote::properties().owner, Comparator.EQ, incrementor)
            .set_limit(1);
        let existing_notes = storage.incrementors.get_notes(options);
        assert(existing_notes.len() == 0, "Incrementor already exists");

        let incrementor_note = IncrementorNote { owner: incrementor };
        let note_emission = storage.incrementors.insert(incrementor_note);
        
        // Emit the note to the incrementor
        note_emission.emit(
            incrementor,
            MessageDelivery.CONSTRAINED_ONCHAIN,
        );

        // Emit the note to the owner
        note_emission.emit(
            sender.unwrap_unchecked(),
            MessageDelivery.CONSTRAINED_ONCHAIN,
        );
    }

    /// @dev Allows the owner to remove an incrementor
    #[external("private")]
    fn remove_incrementor(incrementor: AztecAddress) {
        let sender = context.msg_sender();
        assert(sender.is_some(), "Sender is not set");
        assert_eq(sender.unwrap_unchecked(), storage.owner.read(), "Caller is not owner");
        let options = NoteGetterOptions::new()
            .select(IncrementorNote::properties().owner, Comparator.EQ, incrementor)
            .set_limit(1);
        storage.incrementors.pop_notes(options);
    }


    /// @dev Increments the counter
    #[external("private")]
    fn increment() {
        let sender = context.msg_sender();
        assert(sender.is_some(), "Sender is not set");
        let sender_address = sender.unwrap_unchecked();

        let is_owner = sender_address == storage.owner.read();

        let mut is_incrementor = false;
        if !is_owner {
            // Check if sender has an incrementor note
            let options = NoteGetterOptions::new()
                .select(IncrementorNote::properties().owner, Comparator.EQ, sender_address)
                .set_limit(1);
            let notes = storage.incrementors.get_notes(options);
            is_incrementor = notes.len() > 0;
        }

        assert(is_owner | is_incrementor, "Caller is not owner or incrementor");

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
