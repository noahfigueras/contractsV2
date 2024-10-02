// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { IBeaconOracle } from "./interfaces/IBeaconOracle.sol";
import { Merkle } from "./libraries/Merkle.sol";
import { console } from "forge-std/console.sol";

abstract contract BeaconOracle is IBeaconOracle {
  /// @dev sha256 precompile address.
  uint8 public constant SHA256 = 0x02;
  uint16 public constant SECONDS_PER_EPOCH = 12 * 32;
  uint64 public constant BEACON_GENESIS = 1606824000;
  address public constant BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

  /// @dev Proof that a validator exists
  function verifyValidator(
    bytes32[] calldata validatorProof,
    BeaconChainValidator calldata validator,
    uint256 gIndex,
    uint64 ts
  ) internal view returns(bool) {
    bytes32 validatorRoot = validatorHashTreeRoot(validator);
    bytes32 blockRoot = getParentBlockRoot(ts);

    bytes32 root = Merkle.calculateMerkleRoot(validatorProof, validatorRoot, gIndex);
    if(root != blockRoot) revert InvalidProof();
    
    return true;  
  }

  /// @dev Proof that a validator changed his FEE_RECIPIENT by proposing a block 
  function verifyFeeRecipient(
    uint256[] calldata indices,
    bytes32[] calldata proof,
    uint256 validatorIndex,
    address feeRecipient,
    uint64 timestamp
  ) internal returns(bool) {
    if(indices.length != 2) revert LengthMismatch();

    // Encode values to little endians
    bytes32[] memory leaves = new bytes32[](2);
    leaves[0] = toLittleEndian(validatorIndex);
    leaves[1] = bytes32(uint256(uint160(feeRecipient)) << 96);

    // Calculate root - If verifies, we can use the values
    bytes32 blockRoot = getParentBlockRoot(timestamp);
    bytes32 root = Merkle.calculateMultiMerkleRoot(proof, leaves, indices);
    if(root != blockRoot) revert InvalidProof();

    return true;
  }

  /// @dev eip-4788 precompile contract 
  /// @dev Retrieves Parent Beacon Block Root at timestamp.
  function getParentBlockRoot(uint64 ts) internal view returns (bytes32 root) {
    bytes memory input = abi.encode(ts);

    (bool success, bytes memory data) = BEACON_ROOTS.staticcall(input);
    if (!success || data.length == 0) revert RootNotFound();

    root = abi.decode(data, (bytes32));
  }

  /// @dev Check if validator is active
  function isActiveValidator(BeaconChainValidator calldata validator) internal view returns (bool) {
    uint256 epoch = getEpoch(block.timestamp);
    return (validator.activationEpoch <= epoch) && (validator.exitEpoch > epoch);
  }

  /// @dev Computes epoch from timestamp
  function getEpoch(uint256 timestamp) internal pure returns(uint256) {
    return (timestamp - BEACON_GENESIS) / SECONDS_PER_EPOCH; 
  }

  /// @dev Converts withdrawals credentials to address
  function withdrawalToAddress(bytes32 withdrawal) internal pure returns(address) {
    if(withdrawal[0] == 0x00) { revert InvalidWithdrawalAddr(); }
    return address(uint160(uint256(withdrawal)));
  }

  function validatorHashTreeRoot(BeaconChainValidator memory validator)
      internal
      view
      returns (bytes32 root)
  {
      bytes32 pubkeyRoot;

      assembly {
          // Dynamic data types such as bytes are stored at the specified offset.
          let offset := mload(validator)
          // Call sha256 precompile with the pubkey pointer
          let result :=
              staticcall(gas(), SHA256, add(offset, 32), 0x40, 0x00, 0x20)
          // Precompile returns no data on OutOfGas error.
          if eq(result, 0) { revert(0, 0) }

          pubkeyRoot := mload(0x00)
      }

      bytes32[8] memory nodes = [
          pubkeyRoot,
          validator.withdrawalCredentials,
          toLittleEndian(validator.effectiveBalance),
          toLittleEndian(validator.slashed),
          toLittleEndian(validator.activationEligibilityEpoch),
          toLittleEndian(validator.activationEpoch),
          toLittleEndian(validator.exitEpoch),
          toLittleEndian(validator.withdrawableEpoch)
      ];

      // TODO: Extract to a function accepting a dynamic array of bytes32?
      /// @solidity memory-safe-assembly
      assembly {
          // Count of nodes to hash
          let count := 8

          // Loop over levels
          for { } 1 { } {
              // Loop over nodes at the given depth

              // Initialize `offset` to the offset of `proof` elements in memory.
              let target := nodes
              let source := nodes
              let end := add(source, shl(5, count))

              for { } 1 { } {
                  // Read next two hashes to hash
                  mstore(0x00, mload(source))
                  mstore(0x20, mload(add(source, 0x20)))

                  // Call sha256 precompile
                  let result :=
                      staticcall(gas(), SHA256, 0x00, 0x40, 0x00, 0x20)

                  if eq(result, 0) { revert(0, 0) }

                  // Store the resulting hash at the target location
                  mstore(target, mload(0x00))

                  // Advance the pointers
                  target := add(target, 0x20)
                  source := add(source, 0x40)

                  if iszero(lt(source, end)) { break }
              }

              count := shr(1, count)
              if eq(count, 1) {
                  root := mload(0x00)
                  break
              }
          }
      }
  }

  // forgefmt: disable-next-item
  function toLittleEndian(uint256 v) internal pure returns (bytes32) {
      v =
          ((v &
              0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >>
              8) |
          ((v &
              0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) <<
              8);
      v =
          ((v &
              0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >>
              16) |
          ((v &
              0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) <<
              16);
      v =
          ((v &
              0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >>
              32) |
          ((v &
              0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) <<
              32);
      v =
          ((v &
              0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >>
              64) |
          ((v &
              0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) <<
              64);
      v = (v >> 128) | (v << 128);
      return bytes32(v);
  }

  function toLittleEndian(bool v) internal pure returns (bytes32) {
      return bytes32(v ? 1 << 248 : 0);
  }

}
