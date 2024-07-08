use hex;
use serde_json::Value;
use ssz_rs::prelude::*;

const MAX_PROPOSER_SLASHINGS: usize = 16;
const MAX_ATTESTER_SLASHINGS: usize = 2;
const MAX_ATTESTATIONS: usize = 128;
const MAX_DEPOSITS: usize = 16;
const MAX_VOLUNTARY_EXITS: usize = 16;
const MAX_VALIDATORS_PER_COMMITTEE: usize = 2048;
const DEPOSIT_CONTRACT_TREE_DEPTH: usize = 32;
const SYNC_COMMITTEE_SIZE: usize = 512;
const BYTES_PER_LOGS_BLOOM: usize = 256;
const MAX_EXTRA_DATA_BYTES: usize = 32;
const MAX_BYTES_PER_TRANSACTION: usize = 1073741824;
const MAX_BLOB_COMMITMENTS_PER_BLOCK: usize = 4096;
const MAX_BLS_TO_EXECUTION_CHANGES: usize = 16;
const MAX_TRANSACTIONS_PER_PAYLOAD: usize = 1048576;
const MAX_WITHDRAWALS_PER_PAYLOAD: usize = 16;

type ExecutionAddress = [u8; 20];
type Bytes32 = [u8; 32];
type Root = Bytes32;
type Hash32 = Bytes32;
type BLSPubkey = [u8; 48];
type KZGCommitment = [u8; 48];
type BLSSignature = [u8; 96];
type CommitteeIndex = u64;
type Epoch = u64;
type ValidatorIndex = u64;
type WithdrawalIndex = u64;
type Gwei = u64;
type Transaction = List<u8, MAX_BYTES_PER_TRANSACTION>;

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
            deposit_root: Root::from_string(&object["body"]["eth1_data"]["deposit_root"]),
            deposit_count: object["body"]["eth1_data"]["deposit_count"]
                .as_str()
                .unwrap()
                .parse()
                .unwrap(),
            block_hash: Root::from_string(&object["body"]["eth1_data"]["deposit_count"]),
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
        Attestation {
            aggregation_bits: Bitlist::<MAX_VALIDATORS_PER_COMMITTEE>::try_from(vec).unwrap(),
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

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct SignedVoluntaryExit {
    pub message: VoluntaryExit,
    pub signature: BLSSignature,
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct Deposit {
    pub proof: Vector<Bytes32, 33>,
    pub data: DepositData,
}

impl Deposit {
    pub fn from_json(object: &Value) -> Deposit {
        Deposit {
            proof: object["proof"].as_array().unwrap().iter().collect(),
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

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct Withdrawal {
    pub index: WithdrawalIndex,
    pub validator_index: ValidatorIndex,
    pub address: ExecutionAddress,
    pub amount: Gwei,
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct BLSToExecutionChange {
    pub validator_index: ValidatorIndex,
    pub from_bls_pubkey: BLSPubkey,
    pub to_execution_address: ExecutionAddress,
}

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct SignedBLSToExecutionChange {
    pub message: BLSToExecutionChange,
    pub signature: BLSSignature,
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
            randao_reveal: BLSSignature::from_string(&object["body"]["randao_reveal"]),
            eth1_data: Eth1Data::from_json(&object["body"]["eth1_data"]),
            graffiti: Root::from_string(&object["body"]["graffiti"]),
            proposer_slashings: List::<ProposerSlashings, MAX_PROPOSER_SLASHINGS>::try_from(
                object["body"]["proposer_slashings"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| ProposerSlashings::from_json(x))
                    .collect(),
            )
            .unwrap(),
            attester_slashings: List::<AttesterSlashings, MAX_ATTESTER_SLASHINGS>::try_from(
                object["body"]["attester_slashings"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| AttesterSlashings::from_json(x))
                    .collect(),
            )
            .unwrap(),
            attestations: List::<Attestation, MAX_ATTESTATIONS>::try_from(
                object["body"]["attestations"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Attestation::from_json(x))
                    .collect(),
            )
            .unwrap(),
            deposits: List::<Deposit, MAX_DEPOSITS>::try_from(
                object["body"]["deposits"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|x| Deposit::from_json(x))
                    .collect(),
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

trait HexToBytes {
    fn from_string(value: &Value) -> Self;
}

impl HexToBytes for Root {
    fn from_string(value: &Value) -> Root {
        hex::decode(value.as_str().unwrap().get(2..).unwrap())
            .unwrap()
            .try_into()
            .unwrap()
    }
}

impl HexToBytes for BLSSignature {
    fn from_string(value: &Value) -> BLSSignature {
        hex::decode(value.as_str().unwrap().get(2..).unwrap())
            .unwrap()
            .try_into()
            .unwrap()
    }
}

impl HexToBytes for BLSPubkey {
    fn from_string(value: &Value) -> BLSPubkey {
        hex::decode(value.as_str().unwrap().get(2..).unwrap())
            .unwrap()
            .try_into()
            .unwrap()
    }
}

impl HexToBytes for Vec<u8> {
    fn from_string(value: &Value) -> Vec<u8> {
        hex::decode(value.as_str().unwrap().get(2..).unwrap()).unwrap()
    }
}
