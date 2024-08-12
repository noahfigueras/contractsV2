use crate::beacon_block::{
    BeaconBlockHeader, Bytes32, Checkpoint, Eth1Data, Gwei, HexToBytes, Root,
};
use hex;
use serde_json::Value;
use ssz_rs::prelude::*;

const SLOTS_PER_HISTORICAL_ROOT: usize = 8192;
const SLOTS_PER_EPOCH: usize = 32;
const EPOCHS_PER_ETH1_VOTING_PERIOD: usize = 64;
const VALIDATOR_REGISTRY_LIMIT: usize = 1099511627776;
const EPOCHS_PER_HISTORICAL_VECTOR: usize = 65536;
const EPOCHS_PER_SLASHINGS_VECTOR: usize = 8192;
const JUSTIFICATION_BITS_LENGTH: usize = 4;
const HISTORICAL_ROOTS_LIMIT: usize = 16777216;

type Version = [u8; 4];

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct BeaconBlockState {
    pub slot: u64,
    pub proposer_index: u64,
    pub parent_root: Root,
    pub beacon_state: BeaconState,
    pub body_root: Root,
}

impl BeaconBlockState {
    pub fn from_json(object: &Value) -> BeaconBlockState {
        BeaconBlockState {
            slot: object["slot"].as_str().unwrap().parse().unwrap(),
            proposer_index: object["proposer_index"].as_str().unwrap().parse().unwrap(),
            parent_root: Root::from_string(&object["parent_root"]),
            beacon_state: BeaconState::from_json(&object["beacon_state"]),
            body_root: Root::from_string(&object["body_root"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct Fork {
    pub previous_version: Version,
    pub current_version: Version,
    pub epoch: u64,
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct BeaconState {
    pub genesis_time: u64,
    pub genesis_validator_root: Root,
    pub slot: u64,
    pub fork: Fork,
    pub latest_block_header: BeaconBlockHeader,
    pub block_roots: Vector<Root, SLOTS_PER_HISTORICAL_ROOT>,
    pub state_roots: Vector<Root, SLOTS_PER_HISTORICAL_ROOT>,
    pub eth1_data: Eth1Data,
    pub eth1_data_votes: List<Eth1Data, { (EPOCHS_PER_ETH1_VOTING_PERIOD * SLOTS_PER_EPOCH) }>,
    pub eth1_deposit_index: u64,
    pub validators: List<Validator, VALIDATOR_REGISTRY_LIMIT>,
    pub balances: List<Gwei, VALIDATOR_REGISTRY_LIMIT>,
    pub randao_mixes: Vector<Bytes32, EPOCHS_PER_HISTORICAL_VECTOR>,
    pub slashings: Vector<Gwei, EPOCHS_PER_SLASHINGS_VECTOR>,
    pub previous_epoch_participation: List<ParticipationFlags, VALIDATOR_REGISTRY_LIMIT>,
    pub current_epoch_participation: List<ParticipationFlags, VALIDATOR_REGISTRY_LIMIT>,
    pub justification_bits: Bitvector<JUSTIFICATION_BITS_LENGTH>,
    pub previous_justified_checkpoint: Checkpoint,
    pub current_justified_checkpoint: Checkpoint,
    pub finalized_checkpoint: Checkpoint,
    pub inactivity_scores: List<u64, VALIDATOR_REGISTRY_LIMIT>,
    pub current_sync_committee: SyncComittee,
    pub next_sync_committee: SyncComittee,
    pub latest_execution_payload_header: ExecutionPayloadHeader,
    pub next_withdrawal_index: WithdrawalIndex,
    pub next_withdrawal_validator_index: ValidatorIndex,
    pub historical_summaries: List<HistoricalSummary, HISTORICAL_ROOTS_LIMIT>,
}

impl BeaconState {
    pub fn from_json(object: &Value) -> BeaconState {
        BeaconState {
            // TODO
        }
    }
}
