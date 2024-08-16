use crate::beacon_block::{BeaconBlockHeader, Checkpoint, Eth1Data, ExecutionPayloadHeader};
use crate::types::*;
use serde_json::Value;
use ssz_rs::prelude::*;

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

impl Fork {
    pub fn from_json(object: &Value) -> Fork {
        Fork {
            previous_version: Version::from_string(&object["previous_version"]),
            current_version: Version::from_string(&object["current_version"]),
            epoch: object["epoch"].as_str().unwrap().parse().unwrap(),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct HistoricalSummary {
    pub block_summary_root: Root,
    pub state_summary_root: Root,
}

impl HistoricalSummary {
    pub fn from_json(object: &Value) -> HistoricalSummary {
        HistoricalSummary {
            block_summary_root: Root::from_string(&object["block_summary_root"]),
            state_summary_root: Root::from_string(&object["state_summary_root"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct SyncCommittee {
    pub pubkeys: Vector<BLSPubkey, SYNC_COMMITTEE_SIZE>,
    pub aggregate_pubkey: BLSPubkey,
}

impl SyncCommittee {
    pub fn from_json(object: &Value) -> SyncCommittee {
        SyncCommittee {
            pubkeys: Vector::<BLSPubkey, SYNC_COMMITTEE_SIZE>::try_from(
                object["pubkeys"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| BLSPubkey::from_string(x))
                    .collect::<Vec<BLSPubkey>>(),
            )
            .unwrap(),
            aggregate_pubkey: BLSPubkey::from_string(&object["aggregate_pubkey"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct Validator {
    pub pubkey: BLSPubkey,
    pub withdrawal_credentials: Bytes32,
    pub effective_balance: Gwei,
    pub slashed: bool,
    pub activation_eligibility_epoch: Epoch,
    pub activation_epoch: Epoch,
    pub exit_epoch: Epoch,
    pub withdrawable_epoch: Epoch,
}

impl Validator {
    pub fn from_json(object: &Value) -> Validator {
        Validator {
            pubkey: BLSPubkey::from_string(&object["pubkey"]),
            withdrawal_credentials: Bytes32::from_string(&object["withdrawal_credentials"]),
            effective_balance: object["effective_balance"]
                .as_str()
                .unwrap()
                .parse()
                .unwrap(),
            slashed: object["slashed"].as_bool().unwrap(),
            activation_eligibility_epoch: object["activation_eligibility_epoch"]
                .as_str()
                .unwrap()
                .parse()
                .unwrap(),
            activation_epoch: object["activation_epoch"]
                .as_str()
                .unwrap()
                .parse()
                .unwrap(),
            exit_epoch: object["exit_epoch"].as_str().unwrap().parse().unwrap(),
            withdrawable_epoch: object["withdrawable_epoch"]
                .as_str()
                .unwrap()
                .parse()
                .unwrap(),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct BeaconState {
    pub genesis_time: u64,
    pub genesis_validators_root: Root,
    pub slot: u64,
    pub fork: Fork,
    pub latest_block_header: BeaconBlockHeader,
    pub block_roots: Vector<Root, SLOTS_PER_HISTORICAL_ROOT>,
    pub state_roots: Vector<Root, SLOTS_PER_HISTORICAL_ROOT>,
    pub historical_roots: List<Root, HISTORICAL_ROOTS_LIMIT>,
    pub eth1_data: Eth1Data,
    pub eth1_data_votes: List<Eth1Data, MAX_ETH1_DATA_VOTES>,
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
    pub current_sync_committee: SyncCommittee,
    pub next_sync_committee: SyncCommittee,
    pub latest_execution_payload_header: ExecutionPayloadHeader,
    pub next_withdrawal_index: WithdrawalIndex,
    pub next_withdrawal_validator_index: ValidatorIndex,
    pub historical_summaries: List<HistoricalSummary, HISTORICAL_ROOTS_LIMIT>,
}

impl BeaconState {
    pub fn from_json(object: &Value) -> BeaconState {
        BeaconState {
            genesis_time: object["genesis_time"].as_str().unwrap().parse().unwrap(),
            genesis_validators_root: Root::from_string(&object["genesis_validators_root"]),
            slot: object["slot"].as_str().unwrap().parse().unwrap(),
            fork: Fork::from_json(&object["fork"]),
            latest_block_header: BeaconBlockHeader::from_json(&object["latest_block_header"]),
            block_roots: Vector::<Root, SLOTS_PER_HISTORICAL_ROOT>::try_from(
                object["block_roots"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Root::from_string(x))
                    .collect::<Vec<Root>>(),
            )
            .unwrap(),
            state_roots: Vector::<Root, SLOTS_PER_HISTORICAL_ROOT>::try_from(
                object["state_roots"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Root::from_string(x))
                    .collect::<Vec<Root>>(),
            )
            .unwrap(),
            historical_roots: List::<Root, HISTORICAL_ROOTS_LIMIT>::try_from(
                object["historical_roots"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Root::from_string(x))
                    .collect::<Vec<Root>>(),
            )
            .unwrap(),
            eth1_data: Eth1Data::from_json(&object["eth1_data"]),
            eth1_data_votes: List::<Eth1Data, MAX_ETH1_DATA_VOTES>::try_from(
                object["eth1_data_votes"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Eth1Data::from_json(x))
                    .collect::<Vec<Eth1Data>>(),
            )
            .unwrap(),
            eth1_deposit_index: object["eth1_deposit_index"]
                .as_str()
                .unwrap()
                .parse()
                .unwrap(),
            validators: List::<Validator, VALIDATOR_REGISTRY_LIMIT>::try_from(
                object["validators"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Validator::from_json(x))
                    .collect::<Vec<Validator>>(),
            )
            .unwrap(),
            balances: List::<Gwei, VALIDATOR_REGISTRY_LIMIT>::try_from(
                object["balances"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| x.as_str().unwrap().parse().unwrap())
                    .collect::<Vec<Gwei>>(),
            )
            .unwrap(),
            randao_mixes: Vector::<Bytes32, EPOCHS_PER_HISTORICAL_VECTOR>::try_from(
                object["randao_mixes"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Bytes32::from_string(x))
                    .collect::<Vec<Bytes32>>(),
            )
            .unwrap(),
            slashings: Vector::<Gwei, EPOCHS_PER_SLASHINGS_VECTOR>::try_from(
                object["slashings"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| x.as_str().unwrap().parse().unwrap())
                    .collect::<Vec<Gwei>>(),
            )
            .unwrap(),
            previous_epoch_participation:
                List::<ParticipationFlags, VALIDATOR_REGISTRY_LIMIT>::try_from(
                    object["previous_epoch_participation"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .map(|x| x.as_str().unwrap().parse().unwrap())
                        .collect::<Vec<ParticipationFlags>>(),
                )
                .unwrap(),
            current_epoch_participation:
                List::<ParticipationFlags, VALIDATOR_REGISTRY_LIMIT>::try_from(
                    object["current_epoch_participation"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .map(|x| x.as_str().unwrap().parse().unwrap())
                        .collect::<Vec<ParticipationFlags>>(),
                )
                .unwrap(),
            justification_bits: Bitvector::<JUSTIFICATION_BITS_LENGTH>::try_from(
                Vec::<u8>::from_string(&object["justification_bits"]).as_slice(),
            )
            .unwrap(),
            previous_justified_checkpoint: Checkpoint::from_json(
                &object["previous_justified_checkpoint"],
            ),
            current_justified_checkpoint: Checkpoint::from_json(
                &object["current_justified_checkpoint"],
            ),
            finalized_checkpoint: Checkpoint::from_json(&object["finalized_checkpoint"]),
            inactivity_scores: List::<u64, VALIDATOR_REGISTRY_LIMIT>::try_from(
                object["inactivity_scores"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| x.as_str().unwrap().parse().unwrap())
                    .collect::<Vec<u64>>(),
            )
            .unwrap(),
            current_sync_committee: SyncCommittee::from_json(&object["current_sync_committee"]),
            next_sync_committee: SyncCommittee::from_json(&object["next_sync_committee"]),
            latest_execution_payload_header: ExecutionPayloadHeader::from_json(
                &object["latest_execution_payload_header"],
            ),
            next_withdrawal_index: object["next_withdrawal_index"]
                .as_str()
                .unwrap()
                .parse()
                .unwrap(),
            next_withdrawal_validator_index: object["next_withdrawal_validator_index"]
                .as_str()
                .unwrap()
                .parse()
                .unwrap(),
            historical_summaries: List::<HistoricalSummary, HISTORICAL_ROOTS_LIMIT>::try_from(
                object["historical_summaries"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| HistoricalSummary::from_json(x))
                    .collect::<Vec<HistoricalSummary>>(),
            )
            .unwrap(),
        }
    }
}
