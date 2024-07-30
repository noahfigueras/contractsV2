declare const Buffer;

import { ApiClientResponse, getClient } from '@lodestar/api';
import { config } from '@lodestar/config/default';
import { ssz } from '@lodestar/types';
import { 
  concatGindices, 
  createProof, 
  ProofType,
  Tree
} from '@chainsafe/persistent-merkle-tree';
import { 
  fromHexString,
  toHexString
} from "@chainsafe/ssz";
import {digest, digest64, SHA256} from "@chainsafe/as-sha256";


const BeaconState = ssz.deneb.BeaconState;
const BeaconBlock = ssz.deneb.BeaconBlock;
const beaconNodeUrl = 'http://testing.mainnet.beacon-api.nimbus.team';
const client = getClient(
  { baseUrl: beaconNodeUrl, timeoutMs: 60_000 },
  { config }
);

async function fee_recipient_proof(slot = '9381273') {
  // Query Beacon slot
  /*
  let res;
  res = await client.beacon.getBlockV2(slot);
  if(!res.ok) { throw res.error }

  const blockView = BeaconBlock.toView(res.response.data.message);
  const tree = blockView.tree.clone();
  const gIndices = [
    blockView.type.getPathInfo(['proposer_index']).gindex,
    blockView.type.getPathInfo(['body', 'execution_payload', 'fee_recipient']).gindex,
    blockView.type.getPathInfo(['body', 'execution_payload', 'timestamp']).gindex,
  ];
  const leaves = [
    ssz.ValidatorIndex.serialize(blockView.proposerIndex),
    ssz.ExecutionAddress.serialize(blockView.body.executionPayload.feeRecipient),
    ssz.UintBn64.serialize(BigInt(blockView.body.executionPayload.timestamp))
  ];

  const proof = createProof(tree.rootNode, { 
    type: ProofType.treeOffset, gindices: gIndices 
  });

  const data = {
    proof: proof.leaves.map(x => toHexString(x)),
    indices: [],
    validatorIndex: blockView.proposerIndex,
    feeRecipient: toHexString(blockView.body.executionPayload.feeRecipient),
    timestamp: blockView.body.executionPayload.timestamp
  };
  data.indices = [
    data.proof.indexOf(toHexString(leaves[0]).padEnd(66, "0")),
    data.proof.indexOf(toHexString(leaves[1]).padEnd(66, "0")),
    data.proof.indexOf(toHexString(leaves[2]).padEnd(66, "0")),
  ];
  console.log(data);

  */
  //console.log(toHexString(blockView.hashTreeRoot()));
  console.log(getHelperIndices([4,10,6]));
  //console.log(proof.leaves.length - 3);
  // TODO -> proofs are the leaves in the tree needed to compute the root with 
  // the leaves (values) provided
  //calculate_multi_merkle_root(leaves, proof.leaves, gIndices);
}

function generalizedIndexSibling(index) {
  return index ^ 1;
}

function generalizedIndexParent(index) {
  return Math.floor(index / 2);
}

function getBranchIndices(treeIndex) {
  let o = [generalizedIndexSibling(treeIndex)];
  while(o[o.length - 1] > 1) {
    o.push(generalizedIndexSibling(generalizedIndexParent(o[o.length - 1])));
  }
  return o.slice(0,o.length -1);
} 

function getPathIndices(treeIndex) {
  let o = [treeIndex];
  while(o[o.length - 1] > 1) {
    o.push(generalizedIndexParent(o[o.length - 1]));
  }
  return o.slice(0,o.length -1);
}

function getHelperIndices(indices) {
  let allHelperIndices = [];
  let allPathIndices = [];
  for(let index of indices) {
    index = Number(index);
    allHelperIndices = allHelperIndices.concat(getBranchIndices(index));
    allPathIndices = allPathIndices.concat(getPathIndices(index));
  } 
  console.log(allHelperIndices);
  console.log(allPathIndices);
  allHelperIndices = allHelperIndices.filter((item, x) => allHelperIndices.indexOf(item) == x );
  return allHelperIndices.filter( x => !allPathIndices.includes(x))
    .sort((a, b) => { return a - b })
    .reverse()
}

function calculate_multi_merkle_root(leaves, proof, indices) {
  const helperIndices = getHelperIndices(indices);
  console.log(helperIndices)
  console.log(proof.length);
  if(
    (leaves.length != indices.length) ||
    (proof.length != helperIndices.length)  
  ) throw new Error("Mismatched indices");

  return 0;
}

async function main(slot = '8891391', validatorIndex = 465789) {

  let res;
  res = await client.debug.getStateV2(slot, 'ssz');
  if(!res.ok) { throw res.error }

  const stateView = BeaconState.deserializeToView(res.response);
  res = await client.beacon.getBlockV2(slot);
  if (!res.ok) { throw res.error }

  const blockView = BeaconBlock.toView(res.response.data.message);
  const blockRoot = blockView.hashTreeRoot();
  const timestamp = blockView.body.executionPayload.timestamp;

  const tree = blockView.tree.clone();
  tree.setNode(blockView.type.getPropertyGindex('stateRoot'), stateView.node);

  // Create a proof for the state of the validator against the block.
  const gI = concatGindices([
    blockView.type.getPathInfo(['stateRoot']).gindex,
    stateView.type.getPathInfo(['validators', validatorIndex]).gindex,
  ]);

  const p = createProof(tree.rootNode, { type: ProofType.single, gindex: gI });
  console.log(
    stateView.type.getPathInfo(['validators', validatorIndex])
  )

  // Since EIP-4788 stores parentRoot, we have to find the descendant block of
  // the block from the state.
  res = await client.beacon.getBlockHeaders({ parentRoot: blockRoot });
  if (!res.ok) {
    throw res.error;
  }

  const nextBlock = res.response.data[0]?.header;
  if (!nextBlock) {
    throw new Error('No block to fetch timestamp from');
  }

  const data = {
    proof: p.witnesses.map(x => toHexString(x)),
    validator: stateView.validators.type.elementType.toJson(stateView.validators.get(validatorIndex)),
    validatorIndex: validatorIndex.toString(),
    blockRoot: toHexString(blockRoot),
    gI: gI.toString(),
    timestamp
  }

  console.log(JSON.stringify(data));
}

async function proof(slot = '9381273') {
  // Verify it with no time restrictions using beacon state
  let res;
  res = await client.debug.getStateV2(slot, 'ssz');
  if(!res.ok) { throw res.error }

  const stateView = BeaconState.deserializeToView(res.response);
  res = await client.beacon.getBlockV2(slot);
  if (!res.ok) { throw res.error }

  const blockView = BeaconBlock.toView(res.response.data.message);
  const blockRoot = blockView.hashTreeRoot();
  const timestamp = blockView.body.executionPayload.timestamp;

  const tree = blockView.tree.clone();
  tree.setNode(blockView.type.getPropertyGindex('stateRoot'), stateView.node);

  // Create a proof for the state of the validator against the block.
  const BlockHashToVerify = '0x3eed01c61a785129b69d6a5022e6f98ab2dd562ef4b4bf6e713c9927608bbc61';
  const gIBlock = concatGindices([
    blockView.type.getPathInfo(['stateRoot']).gindex,
    stateView.type.getPathInfo(['historical_roots', BlockHashToVerify]).gindex,
  ]);

  const gIndices = [
    blockView.type.getPathInfo(['proposer_index']).gindex,
    blockView.type.getPathInfo(['body', 'execution_payload', 'fee_recipient']).gindex,
    blockView.type.getPathInfo(['body', 'execution_payload', 'timestamp']).gindex,
    gIBlock
  ];
  const proof = createProof(tree.rootNode, { 
    type: ProofType.treeOffset, gindices: gIndices 
  });
  console.log(proof);
}
//main();
fee_recipient_proof();
//proof();
