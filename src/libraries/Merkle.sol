// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
  
/// As specified in: 
/// https://github.com/ethereum/consensus-specs/blob/dev/ssz/merkle-proofs.md
import { SSZ } from "./SSZ.sol";
import { console } from "forge-std/console.sol";

library Merkle {

  error InvalidIndex();
  error LengthMismatch();

  /// @dev Calculates merkle root
  function calculateMerkleRoot(
    bytes32[] memory _proof, 
    bytes32 leaf,
    uint index
  ) internal pure returns(bytes32) {
    if(_proof.length != uint64(SSZ.log2(index))) revert InvalidIndex();
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
    bytes32[] memory _proof, 
    bytes32[] memory leaves, 
    uint256[] memory indices
  ) internal pure returns(bytes32) {
    if(leaves.length != indices.length) revert LengthMismatch();

    //uint256[] memory helperIndices = get_helper_indices(indices);
    return bytes32(0); 
  }

  
  /// @dev Get the gIndices of all "extra" chunks in the tree needed to prove the
  /// chunks gIndices.
  function getHelperIndices(uint256[] memory indices) internal pure returns(uint256[] memory o) {
    // TODO: Make sure 32 slots is enough.
    uint256[] memory allHelperIndices = new uint256[](32);
    uint256[] memory allPathIndices= new uint256[](32);
    /*
    for(uint256 i = 0; i < indices.length; i++) {
      uint256[] memory branches = getBranchIndices(indices[i]);
      uint256[] memory paths = getPathsIndices(indices[i]);
      for(uint256 i = 0; i < branches.length; i++) {
        allHelperIndices[allHelperIndices.length] = 
      }
      for(uint256 i = 0; i < indices.length; i++) {
        allPathIndices = abi.encodePacked(allPathIndices, getPathIndices(indices[i]));
      }
    }*/
    // TODO -> Remove duplicates and sort in reverse
    //return abi.decode(allHelperIndices, (uint256[]));
    return o;
  }

  /// @dev Get the gIndices of the chunks along the path from the chunk with the 
  /// given tree index to the root.
  function getBranchIndices(uint256 index) internal pure returns(uint256[] memory) {
    uint256[] memory o = new uint256[](index);
    o[0] = generalizedIndexSibling(index);
    while(o[o.length - 1] > 1) {
      o[o.length] = generalizedIndexSibling(generalizedIndexParent(o[o.length - 1]));
    }
    delete o[o.length-1];
    return o;
  }

  /// @dev Get the gIndices of the chunks along the path from the chunk with the 
  /// given tree index to the root.
  function getPathIndices(uint256 index) internal pure returns(uint256[] memory) {
    uint256[] memory o = new uint256[](index);
    o[0] = index;
    while(o[o.length - 1] > 1) {
      o[o.length] = generalizedIndexParent(o[o.length - 1]);
    }
    delete o[o.length-1];
    return o;
  }

  function generalizedIndexParent(uint256 index) internal pure returns(uint256) {
    return index / 2;
  }

  function generalizedIndexSibling(uint256 index) internal pure returns(uint256) {
    return index ^ 1;
  }

}
