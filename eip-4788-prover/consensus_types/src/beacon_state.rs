use hex;
use serde_json::Value;
use ssz_rs::prelude::*;

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct BeaconBlockState {
    pub slot: u64,
    pub proposer_index: u64,
    pub parent_root: Root,
    pub state_root: Root,
    pub body_root: Root,
}

impl BeaconBlockState {
    pub fn from_json(object: &Value) -> BeaconBlockHeader {
        BeaconBlockHeader {
            slot: object["slot"].as_str().unwrap().parse().unwrap(),
            proposer_index: object["proposer_index"].as_str().unwrap().parse().unwrap(),
            parent_root: Root::from_string(&object["parent_root"]),
            beacon_state: BeaconState::from_json(&object["beacon_state"]),
            body_root: Root::from_string(&object["body_root"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct BeaconState {
    pub genesis_time: u64,
    pub genesis_validator_root: Root,
    pub parent_root: Root,
    pub state_root: Root,
    pub body_root: Root,
}
