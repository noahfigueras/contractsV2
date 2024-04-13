import { ApiClientResponse, getClient } from '@lodestar/api';
import { config } from '@lodestar/config/default';
import { ssz } from '@lodestar/types';
import { 
  concatGindices, 
  createProof, 
  ProofType 
} from '@chainsafe/persistent-merkle-tree';
import { 
  fromHexString,
  toHexString
} from "@chainsafe/ssz";

const BeaconState = ssz.deneb.BeaconState;
const BeaconBlock = ssz.deneb.BeaconBlock;

async function main(slot = 'finalized', validatorIndex = 0) {
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

  const tree = blockView.tree.clone();
  tree.setNode(blockView.type.getPropertyGindex('stateRoot'), stateView.node);

  // Create a proof for the state of the validator against the block.
  const gI = concatGindices([
    blockView.type.getPathInfo(['stateRoot']).gindex,
    stateView.type.getPathInfo(['validators', validatorIndex]).gindex,
  ]);

  const p = createProof(tree.rootNode, { type: ProofType.single, gindex: gI });

  const data = {
    blockRoot: toHexString(blockRoot),
    proof: p.witnesses.map(x => toHexString(x)),
    validator: stateView.validators.type.elementType.toJson(stateView.validators.get(validatorIndex)),
    gI
  }
  console.log(data);
}

main();
