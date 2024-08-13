use crate::types::*;
use serde_json::Value;
use ssz_rs::prelude::*;

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct SignedBeaconBlockHeader {
    pub message: BeaconBlockHeader,
    pub signature: BLSSignature,
}

impl SignedBeaconBlockHeader {
    pub fn from_json(object: &Value) -> SignedBeaconBlockHeader {
        SignedBeaconBlockHeader {
            message: BeaconBlockHeader::from_json(&object["message"]),
            signature: BLSSignature::from_string(&object["signature"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct ProposerSlashings {
    pub signed_header1: SignedBeaconBlockHeader,
    pub signed_header2: SignedBeaconBlockHeader,
}

impl ProposerSlashings {
    pub fn from_json(object: &Value) -> ProposerSlashings {
        ProposerSlashings {
            signed_header1: SignedBeaconBlockHeader::from_json(&object["signed_header1"]),
            signed_header2: SignedBeaconBlockHeader::from_json(&object["signed_header2"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct AttesterSlashings {
    pub signed_header1: SignedBeaconBlockHeader,
    pub signed_header2: SignedBeaconBlockHeader,
}

impl AttesterSlashings {
    pub fn from_json(object: &Value) -> AttesterSlashings {
        AttesterSlashings {
            signed_header1: SignedBeaconBlockHeader::from_json(&object["signed_header1"]),
            signed_header2: SignedBeaconBlockHeader::from_json(&object["signed_header2"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct Eth1Data {
    pub deposit_root: Root,
    pub deposit_count: u64,
    pub block_hash: Bytes32,
}

impl Eth1Data {
    pub fn from_json(object: &Value) -> Eth1Data {
        Eth1Data {
            deposit_root: Root::from_string(&object["deposit_root"]),
            deposit_count: object["deposit_count"].as_str().unwrap().parse().unwrap(),
            block_hash: Root::from_string(&object["block_hash"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct Checkpoint {
    pub epoch: Epoch,
    pub root: Root,
}

impl Checkpoint {
    pub fn from_json(object: &Value) -> Checkpoint {
        Checkpoint {
            epoch: object["epoch"].as_str().unwrap().parse().unwrap(),
            root: Root::from_string(&object["root"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct AttestationData {
    pub slot: u64,
    pub index: CommitteeIndex,
    pub beacon_block_root: Root,
    pub source: Checkpoint,
    pub target: Checkpoint,
}

impl AttestationData {
    pub fn from_json(object: &Value) -> AttestationData {
        AttestationData {
            slot: object["slot"].as_str().unwrap().parse().unwrap(),
            index: object["index"].as_str().unwrap().parse().unwrap(),
            beacon_block_root: Root::from_string(&object["beacon_block_root"]),
            source: Checkpoint::from_json(&object["source"]),
            target: Checkpoint::from_json(&object["target"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct Attestation {
    pub aggregation_bits: Bitlist<MAX_VALIDATORS_PER_COMMITTEE>,
    pub data: AttestationData,
    pub signature: BLSSignature,
}

impl Attestation {
    pub fn from_json(object: &Value) -> Attestation {
        let bytes = Vec::<u8>::from_string(&object["aggregation_bits"]);
        Attestation {
            aggregation_bits: Bitlist::<MAX_VALIDATORS_PER_COMMITTEE>::try_from(bytes.as_slice())
                .unwrap(),
            data: AttestationData::from_json(&object["data"]),
            signature: BLSSignature::from_string(&object["signature"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct VoluntaryExit {
    pub epoch: Epoch,
    pub validator_index: ValidatorIndex,
}

impl VoluntaryExit {
    pub fn from_json(object: &Value) -> VoluntaryExit {
        VoluntaryExit {
            epoch: object["epoch"].as_str().unwrap().parse().unwrap(),
            validator_index: object["validator_index"].as_str().unwrap().parse().unwrap(),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct SignedVoluntaryExit {
    pub message: VoluntaryExit,
    pub signature: BLSSignature,
}

impl SignedVoluntaryExit {
    pub fn from_json(object: &Value) -> SignedVoluntaryExit {
        SignedVoluntaryExit {
            message: VoluntaryExit::from_json(&object["message"]),
            signature: BLSSignature::from_string(&object["signature"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct Deposit {
    pub proof: Vector<Bytes32, 33>,
    pub data: DepositData,
}

impl Deposit {
    pub fn from_json(object: &Value) -> Deposit {
        let mut proof = vec![];
        for p in object["proof"].as_array().unwrap().iter() {
            proof.push(Root::from_string(p));
        }
        Deposit {
            proof: proof.try_into().unwrap(),
            data: DepositData::from_json(&object["data"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct DepositData {
    pub pubkey: BLSPubkey,
    pub withdrawal_credentials: Bytes32,
    pub amount: Gwei,
}

impl DepositData {
    pub fn from_json(object: &Value) -> DepositData {
        DepositData {
            pubkey: BLSPubkey::from_string(&object["pubkey"]),
            withdrawal_credentials: Root::from_string(&object["withdrawal_credentials"]),
            amount: object["amount"].as_str().unwrap().parse().unwrap(),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct SyncAggregate {
    pub sync_committee_bits: Bitvector<SYNC_COMMITTEE_SIZE>,
    pub sync_committee_signature: BLSSignature,
}

impl SyncAggregate {
    pub fn from_json(object: &Value) -> SyncAggregate {
        SyncAggregate {
            sync_committee_bits: Bitvector::<SYNC_COMMITTEE_SIZE>::try_from(
                Vec::<u8>::from_string(&object["sync_committee_bits"]).as_slice(),
            )
            .unwrap(),
            sync_committee_signature: BLSSignature::from_string(
                &object["sync_committee_signature"],
            ),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct Withdrawal {
    pub index: WithdrawalIndex,
    pub validator_index: ValidatorIndex,
    pub address: ExecutionAddress,
    pub amount: Gwei,
}

impl Withdrawal {
    pub fn from_json(object: &Value) -> Withdrawal {
        Withdrawal {
            index: object["index"].as_str().unwrap().parse().unwrap(),
            validator_index: object["validator_index"].as_str().unwrap().parse().unwrap(),
            address: ExecutionAddress::from_string(&object["address"]),
            amount: object["amount"].as_str().unwrap().parse().unwrap(),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct BLSToExecutionChange {
    pub validator_index: ValidatorIndex,
    pub from_bls_pubkey: BLSPubkey,
    pub to_execution_address: ExecutionAddress,
}

impl BLSToExecutionChange {
    pub fn from_json(object: &Value) -> BLSToExecutionChange {
        BLSToExecutionChange {
            validator_index: object["validator_index"].as_str().unwrap().parse().unwrap(),
            from_bls_pubkey: BLSPubkey::from_string(&object["from_bls_pubkey"]),
            to_execution_address: ExecutionAddress::from_string(&object["to_execution_address"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct SignedBLSToExecutionChange {
    pub message: BLSToExecutionChange,
    pub signature: BLSSignature,
}

impl SignedBLSToExecutionChange {
    pub fn from_json(object: &Value) -> SignedBLSToExecutionChange {
        SignedBLSToExecutionChange {
            message: BLSToExecutionChange::from_json(&object["message"]),
            signature: BLSSignature::from_string(&object["signature"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct ExecutionPayload {
    pub parent_hash: Hash32,
    pub fee_recipient: ExecutionAddress,
    pub state_root: Bytes32,
    pub receipts_root: Bytes32,
    pub logs_bloom: Vector<u8, BYTES_PER_LOGS_BLOOM>,
    pub prev_randao: Bytes32,
    pub block_number: u64,
    pub gas_limit: u64,
    pub gas_used: u64,
    pub timestamp: u64,
    pub extra_data: List<u8, MAX_EXTRA_DATA_BYTES>,
    pub base_fee_per_gas: U256,
    pub block_hash: Hash32,
    pub transactions: List<Transaction, MAX_TRANSACTIONS_PER_PAYLOAD>,
    pub withdrawals: List<Withdrawal, MAX_WITHDRAWALS_PER_PAYLOAD>,
    pub blob_gas_used: u64,
    pub excess_blob_gas: u64,
}

impl ExecutionPayload {
    pub fn from_json(object: &Value) -> ExecutionPayload {
        ExecutionPayload {
            parent_hash: Root::from_string(&object["parent_hash"]),
            fee_recipient: ExecutionAddress::from_string(&object["fee_recipient"]),
            state_root: Root::from_string(&object["state_root"]),
            receipts_root: Root::from_string(&object["receipts_root"]),
            logs_bloom: Vector::<u8, BYTES_PER_LOGS_BLOOM>::try_from(Vec::<u8>::from_string(
                &object["logs_bloom"],
            ))
            .unwrap(),
            prev_randao: Root::from_string(&object["prev_randao"]),
            block_number: object["block_number"].as_str().unwrap().parse().unwrap(),
            gas_limit: object["gas_limit"].as_str().unwrap().parse().unwrap(),
            gas_used: object["gas_used"].as_str().unwrap().parse().unwrap(),
            timestamp: object["timestamp"].as_str().unwrap().parse().unwrap(),
            extra_data: List::<u8, MAX_EXTRA_DATA_BYTES>::try_from(Vec::<u8>::from_string(
                &object["extra_data"],
            ))
            .unwrap(),
            base_fee_per_gas: U256::from_str_radix(
                &object["base_fee_per_gas"].as_str().unwrap(),
                10,
            )
            .unwrap(),
            block_hash: Root::from_string(&object["block_hash"]),
            transactions: List::<Transaction, MAX_TRANSACTIONS_PER_PAYLOAD>::try_from(
                object["transactions"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Transaction::from_string(x))
                    .collect::<Vec<Transaction>>(),
            )
            .unwrap(),
            withdrawals: List::<Withdrawal, MAX_WITHDRAWALS_PER_PAYLOAD>::try_from(
                object["withdrawals"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Withdrawal::from_json(x))
                    .collect::<Vec<Withdrawal>>(),
            )
            .unwrap(),
            blob_gas_used: object["blob_gas_used"].as_str().unwrap().parse().unwrap(),
            excess_blob_gas: object["excess_blob_gas"].as_str().unwrap().parse().unwrap(),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct ExecutionPayloadHeader {
    pub parent_hash: Hash32,
    pub fee_recipient: ExecutionAddress,
    pub state_root: Bytes32,
    pub receipts_root: Bytes32,
    pub logs_bloom: Vector<u8, BYTES_PER_LOGS_BLOOM>,
    pub prev_randao: Bytes32,
    pub block_number: u64,
    pub gas_limit: u64,
    pub gas_used: u64,
    pub timestamp: u64,
    pub extra_data: List<u8, MAX_EXTRA_DATA_BYTES>,
    pub base_fee_per_gas: U256,
    pub block_hash: Hash32,
    pub transactions_root: Root,
    pub withdrawals_root: Root,
    pub blob_gas_used: u64,
    pub excess_blob_gas: u64,
}

impl ExecutionPayloadHeader {
    pub fn from_json(object: &Value) -> ExecutionPayloadHeader {
        ExecutionPayloadHeader {
            parent_hash: Root::from_string(&object["parent_hash"]),
            fee_recipient: ExecutionAddress::from_string(&object["fee_recipient"]),
            state_root: Root::from_string(&object["state_root"]),
            receipts_root: Root::from_string(&object["receipts_root"]),
            logs_bloom: Vector::<u8, BYTES_PER_LOGS_BLOOM>::try_from(Vec::<u8>::from_string(
                &object["logs_bloom"],
            ))
            .unwrap(),
            prev_randao: Root::from_string(&object["prev_randao"]),
            block_number: object["block_number"].as_str().unwrap().parse().unwrap(),
            gas_limit: object["gas_limit"].as_str().unwrap().parse().unwrap(),
            gas_used: object["gas_used"].as_str().unwrap().parse().unwrap(),
            timestamp: object["timestamp"].as_str().unwrap().parse().unwrap(),
            extra_data: List::<u8, MAX_EXTRA_DATA_BYTES>::try_from(Vec::<u8>::from_string(
                &object["extra_data"],
            ))
            .unwrap(),
            base_fee_per_gas: U256::from_str_radix(
                &object["base_fee_per_gas"].as_str().unwrap(),
                10,
            )
            .unwrap(),
            block_hash: Root::from_string(&object["block_hash"]),
            transactions_root: Root::from_string(&object["transactions_root"]),
            withdrawals_root: Root::from_string(&object["withdrawals_root"]),
            blob_gas_used: object["blob_gas_used"].as_str().unwrap().parse().unwrap(),
            excess_blob_gas: object["excess_blob_gas"].as_str().unwrap().parse().unwrap(),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct BeaconBlockBody {
    pub randao_reveal: BLSSignature,
    pub eth1_data: Eth1Data,
    pub graffiti: Bytes32,
    pub proposer_slashings: List<ProposerSlashings, MAX_PROPOSER_SLASHINGS>,
    pub attester_slashings: List<AttesterSlashings, MAX_ATTESTER_SLASHINGS>,
    pub attestations: List<Attestation, MAX_ATTESTATIONS>,
    pub deposits: List<Deposit, MAX_DEPOSITS>,
    pub voluntary_exits: List<SignedVoluntaryExit, MAX_VOLUNTARY_EXITS>,
    pub sync_aggregate: SyncAggregate,
    pub execution_payload: ExecutionPayload,
    pub bls_to_execution_changes: List<SignedBLSToExecutionChange, MAX_BLS_TO_EXECUTION_CHANGES>,
    pub blob_kzg_commitments: List<KZGCommitment, MAX_BLOB_COMMITMENTS_PER_BLOCK>,
}

impl BeaconBlockBody {
    pub fn from_json(object: &Value) -> BeaconBlockBody {
        BeaconBlockBody {
            randao_reveal: BLSSignature::from_string(&object["randao_reveal"]),
            eth1_data: Eth1Data::from_json(&object["eth1_data"]),
            graffiti: Root::from_string(&object["graffiti"]),
            proposer_slashings: List::<ProposerSlashings, MAX_PROPOSER_SLASHINGS>::try_from(
                object["proposer_slashings"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| ProposerSlashings::from_json(x))
                    .collect::<Vec<ProposerSlashings>>(),
            )
            .unwrap(),
            attester_slashings: List::<AttesterSlashings, MAX_ATTESTER_SLASHINGS>::try_from(
                object["attester_slashings"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| AttesterSlashings::from_json(x))
                    .collect::<Vec<AttesterSlashings>>(),
            )
            .unwrap(),
            attestations: List::<Attestation, MAX_ATTESTATIONS>::try_from(
                object["attestations"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Attestation::from_json(x))
                    .collect::<Vec<Attestation>>(),
            )
            .unwrap(),
            deposits: List::<Deposit, MAX_DEPOSITS>::try_from(
                object["deposits"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Deposit::from_json(x))
                    .collect::<Vec<Deposit>>(),
            )
            .unwrap(),
            voluntary_exits: List::<SignedVoluntaryExit, MAX_VOLUNTARY_EXITS>::try_from(
                object["voluntary_exits"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| SignedVoluntaryExit::from_json(x))
                    .collect::<Vec<SignedVoluntaryExit>>(),
            )
            .unwrap(),
            sync_aggregate: SyncAggregate::from_json(&object["sync_aggregate"]),
            execution_payload: ExecutionPayload::from_json(&object["execution_payload"]),
            bls_to_execution_changes: List::<
                SignedBLSToExecutionChange,
                MAX_BLS_TO_EXECUTION_CHANGES,
            >::try_from(
                object["bls_to_execution_changes"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| SignedBLSToExecutionChange::from_json(x))
                    .collect::<Vec<SignedBLSToExecutionChange>>(),
            )
            .unwrap(),
            blob_kzg_commitments: List::<KZGCommitment, MAX_BLOB_COMMITMENTS_PER_BLOCK>::try_from(
                object["blob_kzg_commitments"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| KZGCommitment::from_string(x))
                    .collect::<Vec<KZGCommitment>>(),
            )
            .unwrap(),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct BeaconBlockHeader {
    pub slot: u64,
    pub proposer_index: u64,
    pub parent_root: Root,
    pub state_root: Root,
    pub body_root: Root,
}

impl BeaconBlockHeader {
    pub fn from_json(object: &Value) -> BeaconBlockHeader {
        BeaconBlockHeader {
            slot: object["slot"].as_str().unwrap().parse().unwrap(),
            proposer_index: object["proposer_index"].as_str().unwrap().parse().unwrap(),
            parent_root: Root::from_string(&object["parent_root"]),
            state_root: Root::from_string(&object["state_root"]),
            body_root: Root::from_string(&object["body_root"]),
        }
    }
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct BeaconBlock {
    pub slot: u64,
    pub proposer_index: u64,
    pub parent_root: Root,
    pub state_root: Root,
    pub body: BeaconBlockBody,
}

impl BeaconBlock {
    pub fn from_json(object: &Value) -> BeaconBlock {
        BeaconBlock {
            slot: object["slot"].as_str().unwrap().parse().unwrap(),
            proposer_index: object["proposer_index"].as_str().unwrap().parse().unwrap(),
            parent_root: Root::from_string(&object["parent_root"]),
            state_root: Root::from_string(&object["state_root"]),
            body: BeaconBlockBody::from_json(&object["body"]),
        }
    }
}
