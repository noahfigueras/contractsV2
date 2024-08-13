use hex;
use serde_json::Value;
use ssz_rs::prelude::*;

pub const MAX_PROPOSER_SLASHINGS: usize = 16;
pub const MAX_ATTESTER_SLASHINGS: usize = 2;
pub const MAX_ATTESTATIONS: usize = 128;
pub const MAX_DEPOSITS: usize = 16;
pub const MAX_VOLUNTARY_EXITS: usize = 16;
pub const MAX_VALIDATORS_PER_COMMITTEE: usize = 2048;
pub const DEPOSIT_CONTRACT_TREE_DEPTH: usize = 32;
pub const SYNC_COMMITTEE_SIZE: usize = 512;
pub const BYTES_PER_LOGS_BLOOM: usize = 256;
pub const MAX_EXTRA_DATA_BYTES: usize = 32;
pub const MAX_BYTES_PER_TRANSACTION: usize = 1073741824;
pub const MAX_BLOB_COMMITMENTS_PER_BLOCK: usize = 4096;
pub const MAX_BLS_TO_EXECUTION_CHANGES: usize = 16;
pub const MAX_TRANSACTIONS_PER_PAYLOAD: usize = 1048576;
pub const MAX_WITHDRAWALS_PER_PAYLOAD: usize = 16;
pub const SLOTS_PER_HISTORICAL_ROOT: usize = 8192;
pub const SLOTS_PER_EPOCH: usize = 32;
pub const EPOCHS_PER_ETH1_VOTING_PERIOD: usize = 64;
pub const VALIDATOR_REGISTRY_LIMIT: usize = 1099511627776;
pub const EPOCHS_PER_HISTORICAL_VECTOR: usize = 65536;
pub const EPOCHS_PER_SLASHINGS_VECTOR: usize = 8192;
pub const JUSTIFICATION_BITS_LENGTH: usize = 4;
pub const HISTORICAL_ROOTS_LIMIT: usize = 16777216;
pub const MAX_ETH1_DATA_VOTES: usize = EPOCHS_PER_ETH1_VOTING_PERIOD * SLOTS_PER_EPOCH;

pub type Bits = Vec<bool>;
pub type ExecutionAddress = [u8; 20];
pub type Bytes32 = [u8; 32];
pub type Root = Bytes32;
pub type Hash32 = Bytes32;
pub type BLSPubkey = [u8; 48];
pub type KZGCommitment = Vector<u8, 48>;
pub type BLSSignature = [u8; 96];
pub type CommitteeIndex = u64;
pub type Epoch = u64;
pub type ValidatorIndex = u64;
pub type WithdrawalIndex = u64;
pub type Gwei = u64;
pub type Transaction = List<u8, MAX_BYTES_PER_TRANSACTION>;
pub type Version = [u8; 4];
pub type ParticipationFlags = u8;

#[derive(PartialEq, Eq, Debug, SimpleSerialize)]
pub struct Transaction2 {
    id: u8,
}

pub trait HexToBytes {
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

impl HexToBytes for KZGCommitment {
    fn from_string(value: &Value) -> KZGCommitment {
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

impl HexToBytes for ExecutionAddress {
    fn from_string(value: &Value) -> ExecutionAddress {
        hex::decode(value.as_str().unwrap().get(2..).unwrap())
            .unwrap()
            .try_into()
            .unwrap()
    }
}

impl HexToBytes for Version {
    fn from_string(value: &Value) -> Version {
        hex::decode(value.as_str().unwrap().get(2..).unwrap())
            .unwrap()
            .try_into()
            .unwrap()
    }
}

impl HexToBytes for Transaction {
    fn from_string(value: &Value) -> Transaction {
        hex::decode(value.as_str().unwrap().get(2..).unwrap())
            .unwrap()
            .try_into()
            .unwrap()
    }
}

impl HexToBytes for Transaction2 {
    fn from_string(value: &Value) -> Transaction2 {
        let hex = hex::decode(value.as_str().unwrap().get(2..).unwrap()).unwrap();
        Transaction2 { id: 1 }
    }
}

impl HexToBytes for Vec<u8> {
    fn from_string(value: &Value) -> Vec<u8> {
        hex::decode(value.as_str().unwrap().get(2..).unwrap())
            .unwrap()
            .try_into()
            .unwrap()
    }
}

impl HexToBytes for Bits {
    fn from_string(value: &Value) -> Bits {
        let mut bits: Bits = vec![];
        hex::decode(value.as_str().unwrap().get(2..).unwrap())
            .unwrap()
            .iter()
            .for_each(|x| bits.append(&mut get_bits(x)));
        bits
    }
}

fn get_bits(number: &u8) -> Bits {
    let mut bits: Bits = vec![];
    let mut mask = 0xff;
    while mask != 0 {
        if (number & mask) != 0 {
            bits.push(true);
        } else {
            bits.push(false);
        }
        mask >>= 1;
    }
    bits
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;

    #[test]
    fn it_converts_hex_to_bytes() {
        let data = r#"
            {
                "randao_reveal": "0x8f90dcabf391dc8ac1a1c7e28614e3229c82adece090392c658cdefa61fb3411202ad44feb0bce1e58d03b0a48b1fa8b0f028681a8edadd24d2df792de917213aa767a5bd36a7c23d63c351cdd5df276ccbf60cfd478f58d558c4e9898e33b13"
            }
        "#;
        let v: Value = serde_json::from_str(data).unwrap();

        let res = BLSSignature::from_string(&v["randao_reveal"]);

        assert_ne!(Some(res), None);
    }

    #[test]
    fn it_decodes_transaction() {
        // leaf -> 0x22f560a3e653dfd45dc7693214b5788f3838c87043819e33903828faa4b62c40
        let res = Transaction2::from_string("0x02f8d301830bd698839c118f8501356d9f8983015f90940fac79e4e1346f160037e76a5238fee2617a4d3180b864c8fea2fb000000000000000000000000e03c23519e18d64f144d2800e30e81b0065c48b50000000000000000000000000f5d2fb29fb7d3cfee444a200298f468908cc9420000000000000000000000000000000000000000000000049a2413365a030000c001a0afdcb150943ba80d508daab4675dbc9a1494b73c7f71edbdaec222857edad428a04a5b044cbf841d474a0064787b3b22d6792b63ddc95793f8e5f3243bd5b2bb75");

        assert_ne!(Some(res), None);
    }
}
