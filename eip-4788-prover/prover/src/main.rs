use consensus_types::{
    beacon_block::BeaconBlock,
    beacon_state::BeaconState,
    beacon_state::BeaconBlockState,
};
use ssz_rs::prelude::*;
use serde_json::{ from_str, Value };
use std::fs;
use reqwest::Result;
use std::time::Duration;
use reqwest::ClientBuilder;

#[tokio::main]
async fn main() -> Result<()> {
    /*
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
    */
    let timeout = Duration::new(60, 0);
    let client = ClientBuilder::new().timeout(timeout).build()?;

    let slot = 9312425;
    let beacon_url = format!(
        "http://unstable.mainnet.beacon-api.nimbus.team/eth/v2/beacon/blocks/{slot}",
        slot = slot
    );

    let response = client.get(&beacon_url).send().await?;
    if response.status().is_success() {
        let text = response.text().await?;
        let json: Value = from_str(text.as_str()).unwrap();
        let block: BeaconBlock = BeaconBlock::from_json(&json["data"]["message"]);
        let (proof, witness) = block.multi_prove(&[
            &["proposer_index".into()],
            &["body".into(), "execution_payload".into(), "fee_recipient".into()],
        ]).unwrap();
        dbg!(&proof, &witness);
    } else {
        dbg!("Error: API call unsuccessful");
    }

    Ok(())
}
