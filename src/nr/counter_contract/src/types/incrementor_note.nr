use aztec::{macros::notes::note, protocol_types::{address::AztecAddress, traits::Packable}};

#[derive(Packable, Eq)]
#[note]
pub struct IncrementorNote {
    pub owner: AztecAddress,
}
