pub mod consensus_types;
use consensus_types::BeaconBlock;
use ssz_rs::prelude::*;
use serde_json::{ from_str, Value };
use std::fs;

#[tokio::main]
async fn main() {
    // Fetch BeaconState
    //let url = "http://unstable.mainnet.beacon-api.nimbus.team/eth/v2/beacon/blocks/9312425";
    // Load from File
    let file2 = fs::read_to_string("block.json").unwrap();

    let json2: Value = from_str(file2.as_str()).unwrap();

    let block: BeaconBlock = BeaconBlock::from_json(&json2);

    let (proof, witness) = block.multi_prove(&[
        &["proposer_index".into()],
        &["body".into(), "execution_payload".into(), "fee_recipient".into()],
        &["body".into(), "execution_payload".into(), "timestamp".into()]
    ]).unwrap();

    dbg!(&proof);
    assert!(proof.verify(witness).is_ok());
}
