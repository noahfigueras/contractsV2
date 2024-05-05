// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { SSZ } from "./SSZ.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { IBeaconOracle } from "./interfaces/IBeaconOracle.sol";

contract BeaconOracle is IBeaconOracle {
  uint8 public constant SLOTS_PER_EPOCH = 32; // Mainnet
  uint32 public constant BLOCK_TO_SLOT_DIFF = 10797349; // Mainnet
  address public constant BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

  function verifyValidator(
    bytes32[] calldata validatorProof,
    SSZ.Validator calldata validator,
    uint256 gIndex,
    uint64 ts
  ) public view returns(bool) {
    bytes32 validatorRoot = SSZ.validatorHashTreeRoot(validator);
    bytes32 blockRoot = getParentBlockRoot(ts);
    address caller = withdrawalToAddress(validator.withdrawalCredentials);

    bytes32 root = calculate_merkle_root(validatorProof, validatorRoot, gIndex);
    if(root != blockRoot) revert InvalidProof();
    if(caller != msg.sender) revert UnauthorizedCaller();
    if(!isActiveValidator(validator)) revert InactiveValidator();
    
    return true;  
  }

  /// @dev eip-4788 precompile contract 
  /// @dev Retrieves Parent Beacon Block Root at timestamp.
  function getParentBlockRoot(uint64 ts) public view returns (bytes32 root) {
    bytes memory input = abi.encode(ts);

    (bool success, bytes memory data) = BEACON_ROOTS.staticcall(input);
    if (!success || data.length == 0) revert RootNotFound();

    root = abi.decode(data, (bytes32));
  }

  /// @dev Calculates merkle root as specified by 
  /// https://github.com/ethereum/consensus-specs/blob/dev/ssz/merkle-proofs.md
  function calculate_merkle_root(
    bytes32[] memory _proof, 
    bytes32 leaf,
    uint index
  ) public pure returns(bytes32) {
    if(_proof.length != uint64(log2(index))) revert InvalidIndex();
    for(uint256 i = 0; i < _proof.length; i++) {
      if((index & (1 << i)) > 0) {
        leaf = sha256(abi.encode(_proof[i], leaf));
      } else {
        leaf = sha256(abi.encode(leaf, _proof[i]));
      }
    }
    return leaf;
  }

  /// @dev Check if validator is active
  function isActiveValidator(SSZ.Validator calldata validator) public view returns (bool) {
    uint256 epoch = getEpochAtBlock(block.number);
    return (validator.activationEpoch <= epoch) && (validator.exitEpoch > epoch);
  }

  /// @dev Computes epoch from block.number 
  function getEpochAtBlock(uint256 _block) internal pure returns(uint256) {
    return (_block - BLOCK_TO_SLOT_DIFF) / SLOTS_PER_EPOCH; 
  }

  /// @dev Converts withdrawals credentials to address
  function withdrawalToAddress(bytes32 withdrawal) internal pure returns(address) {
    return address(uint160(uint256(withdrawal)));
  }

  /// @dev From solady FixedPointMath
  /// @dev Returns the log2 of `x`.
  /// Equivalent to computing the index of the most significant bit (MSB) of `x`.
  function log2(uint256 x) internal pure returns (uint256 r) {
    /// @solidity memory-safe-assembly
    assembly {
      if iszero(x) {
        // Store the function selector of `Log2Undefined()`.
        mstore(0x00, 0x5be3aa5c)
        // Revert with (offset, size).
        revert(0x1c, 0x04)
      }

      r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
      r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
      r := or(r, shl(5, lt(0xffffffff, shr(r, x))))

      // For the remaining 32 bits, use a De Bruijn lookup.
      // See: https://graphics.stanford.edu/~seander/bithacks.html
      x := shr(r, x)
      x := or(x, shr(1, x))
      x := or(x, shr(2, x))
      x := or(x, shr(4, x))
      x := or(x, shr(8, x))
      x := or(x, shr(16, x))

      // forgefmt: disable-next-item
      r := or(r, byte(shr(251, mul(x, shl(224, 0x07c4acdd))),
                      0x0009010a0d15021d0b0e10121619031e080c141c0f111807131b17061a05041f))
    }
  }
}
