pub mod consensus_types;
use consensus_types::{ BeaconBlockHeader, BeaconBlockBody };
use ssz_rs::prelude::*;
use serde_json::{ from_str, Value };
use std::fs;

#[tokio::main]
async fn main() {
    // Fetch BeaconState
    //let url = "http://unstable.mainnet.beacon-api.nimbus.team/eth/v2/beacon/blocks/9312425";
    // Load from File
    let file1 = fs::read_to_string("block_header.json").unwrap();
    let file2 = fs::read_to_string("block.json").unwrap();

    let json1: Value = from_str(file1.as_str()).unwrap();
    let json2: Value = from_str(file2.as_str()).unwrap();

    let block_header: BeaconBlockHeader = BeaconBlockHeader::from_json(&json1);
    let block_body: BeaconBlockBody = BeaconBlockBody::from_json(&json2);

    let (proof, witness) = block_header.prove(&["slot".into()]).unwrap();
    dbg!(witness, proof);

}

/*
 let leaves = [1,2,3,4, a: [b,c,d]];
       root
     /      \
   h12      h34
  /  \     /   \
 h1  h2   h3    h4
/ \  / \  / \   / \
1 2 3  4 a  0  0  0
*/
