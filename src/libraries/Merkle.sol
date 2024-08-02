// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
  
/// As specified in: 
/// https://github.com/ethereum/consensus-specs/blob/dev/ssz/merkle-proofs.md
import { SSZ } from "./SSZ.sol";
import { Arrays } from "./Arrays.sol";

library Merkle {
  using Arrays for uint256[];

  error InvalidProof();

  /// @dev Calculates merkle root
  function calculateMerkleRoot(
    bytes32[] memory _proof, 
    bytes32 leaf,
    uint index
  ) internal pure returns(bytes32) {
    if(_proof.length != uint64(SSZ.log2(index))) revert InvalidProof();
    for(uint256 i = 0; i < _proof.length; i++) {
      if((index & (1 << i)) > 0) {
        leaf = sha256(abi.encode(_proof[i], leaf));
      } else {
        leaf = sha256(abi.encode(leaf, _proof[i]));
      }
    }
    return leaf;
  }

  /// @dev Calculates multi-merkle root
  function calculateMultiMerkleRoot(
    bytes32[] memory proof, 
    bytes32[] memory leaves, 
    uint256[] memory indices
  ) internal pure returns(bytes32) {
    if(leaves.length != indices.length) revert InvalidProof();
    uint256[] memory helperIndices = getHelperIndices(indices);
    if(proof.length != helperIndices.length) revert InvalidProof();

    uint256[] memory keys = helperIndices.concat(indices).sortReverse();
    bytes32[] memory objects = new bytes32[](keys[0]);
    for(uint256 i = 0; i < helperIndices.length; i++) {
      objects[helperIndices[i]] = proof[i];
    }
    for(uint256 i = 0; i < indices.length; i++) {
      objects[indices[i]] = leaves[i];
    }

    uint256 pos = 0;
    while(pos < keys.length) {
      uint256 k = keys[pos];
      if(
        objects[k] > 0 && // Has index
        objects[k ^ 1] > 0 && // Has Sibling 
        objects[k / 2] == 0 // No Parent 
      ) {
        objects[k / 2] = sha256(abi.encode(objects[(k | 1) ^ 1], objects[k | 1]));
        keys = keys.push(k / 2);
      }

      pos += 1;
    }

    return objects[1]; 
  }

  
  /// @dev Get the gIndices of all "extra" chunks in the tree needed to prove the
  /// chunks gIndices.
  function getHelperIndices(uint256[] memory indices) internal pure returns(uint256[] memory) {
    uint256[] memory allHelperIndices;
    uint256[] memory allPathIndices;
    for(uint256 i = 0; i < indices.length; i++) {
      allHelperIndices = allHelperIndices.concat(getBranchIndices(indices[i]));
      allPathIndices = allPathIndices.concat(getPathIndices(indices[i]));
    }
    return allHelperIndices.difference(allPathIndices).sortReverse();
  }

  /// @dev Get the gIndices of the chunks along the path from the chunk with the 
  /// given tree index to the root.
  function getBranchIndices(uint256 index) internal pure returns(uint256[] memory) {
    uint256[] memory o = new uint256[](1);
    o[0] = generalizedIndexSibling(index);
    while(o[o.length - 1] > 1) {
      o = o.push(generalizedIndexSibling(generalizedIndexParent(o[o.length - 1])));
    }
    return o.pop();
  }

  /// @dev Get the gIndices of the chunks along the path from the chunk with the 
  /// given tree index to the root.
  function getPathIndices(uint256 index) internal pure returns(uint256[] memory) {
    uint256[] memory o = new uint256[](1);
    o[0] = index;
    while(o[o.length - 1] > 1) {
      o = o.push(generalizedIndexParent(o[o.length - 1]));
    }
    return o.pop();
  }

  function generalizedIndexParent(uint256 index) internal pure returns(uint256) {
    return index / 2;
  }

  function generalizedIndexSibling(uint256 index) internal pure returns(uint256) {
    return index ^ 1;
  }

}
