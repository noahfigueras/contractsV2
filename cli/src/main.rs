use eth2::{types::{ BlockId, StateId} , BeaconNodeHttpClient, Timeouts};
use ssz_rs::prelude::*;
use std::time::Duration;
use types::{
    BeaconState,
    BeaconBlock,
    BeaconBlockDeneb,
    ChainSpec,
    EthSpec,
    MainnetEthSpec,
    Slot,
    Hash256,
};
use tree_hash::TreeHash;
use tree_hash_derive::TreeHash;
use merkle_proof::{
    MerkleTree,
    verify_merkle_proof,
};
use ethereum_hashing::hash32_concat;
use std::fs;
use ssz::{Decode, DecodeError, Encode};

#[tokio::main]
async fn main() {
    // Fetch BeaconState
    let url = "http://unstable.mainnet.beacon-api.nimbus.team";
    let spec = ChainSpec::default();
    let slot = Slot::new(9496284);
    let validator_index = 465789;
    let state = StateId::Slot(slot.clone());
    let timeout = Timeouts::set_all(Duration::from_secs(60*5));
    let client = BeaconNodeHttpClient::new(url.parse().unwrap(), timeout);
    let block = client
        .get_beacon_blocks::<MainnetEthSpec>(BlockId::Slot(slot.clone()))
        .await
        .unwrap().unwrap();


    dbg!(block.data.message().body().blob_kzg_commitments().unwrap().tree_hash_root());
    dbg!(block.data.message().body().blob_kzg_commitments().unwrap().as_ssz_bytes());
    /*
    dbg!(block.data.message().tree_hash_root());
    dbg!(block.data.message().body().randao_reveal().tree_hash_root());
    dbg!(block.data.message().body().eth1_data().tree_hash_root());
    dbg!(block.data.message().body().graffiti().tree_hash_root());
    dbg!(block.data.message().body().proposer_slashings().tree_hash_root());
    dbg!(block.data.message().body().attester_slashings().tree_hash_root());
    dbg!(block.data.message().body().attestations().tree_hash_root());
    dbg!(block.data.message().body().deposits().tree_hash_root());
    dbg!(block.data.message().body().voluntary_exits().tree_hash_root());
    dbg!(block.data.message().body().sync_aggregate().unwrap().tree_hash_root());
    dbg!(block.data.message().body().execution_payload().unwrap().tree_hash_root());
    dbg!(block.data.message().body().bls_to_execution_changes().unwrap().tree_hash_root());
    dbg!(block.data.message().body().blob_kzg_commitments().unwrap().tree_hash_root());

    let mut state = client
        .get_debug_beacon_states_ssz::<MainnetEthSpec>(state, &spec)
        .await
        .unwrap().unwrap();

    // Register - Get Proof of validator x against block_root.
    // 1. Proof of Beacon state against the block
    let block_tree = MerkleTree::create(&[
        slot.tree_hash_root(),
        block.data.message().proposer_index().tree_hash_root(),
        block.data.parent_root().tree_hash_root(),
        state.tree_hash_root(),
        block.data.message().body_root()
    ], 3);
    let (_, mut proof) = block_tree.generate_proof(3,3).unwrap();

    // 2. Proof of Validators against State
    // Get all Beacon State leaves
    state.initialize_tree_hash_cache();
    let mut cache = state.tree_hash_cache_mut().take()
        .expect("Tree Hash Not Initialized");
    let leaves = cache.recalculate_tree_hash_leaves(&state).unwrap();
    state.tree_hash_cache_mut().restore(cache);
    // Use the depth of the `BeaconState` fields (i.e. `log2(32) = 5`).
    let tree = MerkleTree::create(&leaves, 5);
    let (_, mut proof_state) = tree.generate_proof(11,5).unwrap();
    proof_state.append(&mut proof);

    // 3. Proof of Validator at index against Validators
    let validator_limit = (2 as i64).pow(40) as usize;
    let leaves: Vec<Hash256> = state.validators()
        .iter()
        .map(|v| v.tree_hash_root())
        .collect();

    let depth = validator_limit.next_power_of_two().ilog2() as usize;
    let tree = MerkleTree::create(&leaves, depth);
    let (leaf, mut proof_validator) = tree.generate_proof(validator_index,depth).unwrap();

    // Add mix_in_length
    let length = state.validators().len();
    let usize_len = std::mem::size_of::<usize>();
    let mut length_bytes = vec![0; 32];
    length_bytes.get_mut(0..usize_len).unwrap().copy_from_slice(&length.to_le_bytes());
    let length_root = Hash256::from_slice(length_bytes.as_slice());
    proof_validator.push(length_root);
    proof_validator.append(&mut proof_state);

    // gIndex = 2**depth + index
    let g_index = (2 as u64).pow((depth+1) as u32) + validator_index as u64;
    let index = concat_generalized_indices(vec![11,43, g_index]);

    dbg!(
        verify_merkle_proof(
            leaf,
            &proof_validator,
            proof_validator.len(),
            index as usize,
            block_tree.hash()
        )
    );
    dbg!(leaf, proof_validator, block_tree.hash(), index);
    // Slashing - Prove that validator x has missed a slot.
    // Slashing - Prove that validator x has proposed a block with incorrect fee_recipient.
    // Slashing - Prove that validator x has changed fee_recipient.
    */

}

fn concat_generalized_indices(indices: Vec<u64>) -> u64 {
    let mut o = 1;
    for i in indices.iter() {
        o = o * floor_power_of_two(*i) + (i - floor_power_of_two(*i));
    }
    o
}

fn floor_power_of_two(mut x: u64) -> u64 {
    if x == 0 {
        return 0;
    }
    // Extend bit shifts to handle 64-bit
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    x |= x >> 32;  // Additional shift necessary for 64-bit integers
    // After filling bits, the highest power of 2 <= x will be (x + 1) / 2
    x = x + 1;
    x >> 1
}
