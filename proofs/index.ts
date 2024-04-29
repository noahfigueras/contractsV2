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

async function main(slot = '8891391', validatorIndex = 465789) {
  const beaconNodeUrl = 'http://testing.mainnet.beacon-api.nimbus.team';
  const client = getClient(
    { baseUrl: beaconNodeUrl, timeoutMs: 60_000 },
    { config }
  );

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
main();
