use consensus_types::{
    beacon_block::BeaconBlock,
    beacon_state::BeaconState,
};
use ssz_rs::prelude::*;
use serde_json::{ from_str, Value };
use std::fs;

#[tokio::main]
async fn main() {
    // Load from File
    let beacon_block = fs::read_to_string("data/block.json").unwrap();
    let beacon_state = fs::read_to_string("data/beacon_state@9727474.json").unwrap();

    let beacon_block_json: Value = from_str(beacon_block.as_str()).unwrap();
    let beacon_state_json: Value = from_str(beacon_state.as_str()).unwrap();

    let block: BeaconBlock = BeaconBlock::from_json(&beacon_block_json);
    //let state: BeaconState = BeaconState::from_json(&beacon_state_json["data"]);

    let (proof, witness) = block.prove(&["slot".into()]).unwrap();
    dbg!(&proof, &witness);
    assert!(proof.verify(witness).is_ok());
}
