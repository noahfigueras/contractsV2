pub mod consensus_types;
use consensus_types::{ BeaconBlockHeader, BeaconBlockBody, BeaconBlock };
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
    //let block_body: BeaconBlockBody = BeaconBlockBody::from_json(&json2);
    let block: BeaconBlock = BeaconBlock::from_json(&json2);

    //let (proof, witness) = block_header.prove(&["slot".into()]).unwrap();
    //dbg!(witness, proof);

    dbg!(block_header.hash_tree_root());
    dbg!(block.hash_tree_root());
    dbg!(block.body.randao_reveal.hash_tree_root());
    dbg!(block.body.eth1_data.hash_tree_root());
    dbg!(block.body.graffiti.hash_tree_root());
    dbg!(block.body.proposer_slashings.hash_tree_root());
    dbg!(block.body.attester_slashings.hash_tree_root());
    dbg!(block.body.attestations.hash_tree_root());
    dbg!(block.body.deposits.hash_tree_root());
    dbg!(block.body.voluntary_exits.hash_tree_root());
    dbg!(block.body.sync_aggregate.hash_tree_root());
    dbg!(block.body.execution_payload.hash_tree_root());
    dbg!(block.body.bls_to_execution_changes.hash_tree_root());
    dbg!(block.body.blob_kzg_commitments.hash_tree_root());
    dbg!(&block.body.blob_kzg_commitments.chunks());
    dbg!(&block.body.blob_kzg_commitments.len());
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
