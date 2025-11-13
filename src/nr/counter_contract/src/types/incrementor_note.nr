use aztec::{
    macros::notes::note,
    oracle::random::random,
    protocol_types::{address::AztecAddress, traits::Packable},
};

#[derive(Packable, Eq)]
#[note]
pub struct IncrementorNote {
    pub owner: AztecAddress,
    randomness: Field,
}

impl IncrementorNote {
    pub fn new(owner: AztecAddress) -> Self {
        let randomness = unsafe { random() };
        AddressNote { owner, randomness }
    }
}
