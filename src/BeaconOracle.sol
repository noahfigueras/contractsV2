// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { SSZ } from "./libraries/SSZ.sol";
import { IBeaconOracle } from "./interfaces/IBeaconOracle.sol";
import { Merkle } from "./libraries/Merkle.sol";

contract BeaconOracle is IBeaconOracle {
  uint8 public constant SLOTS_PER_EPOCH = 32; // Mainnet
  uint32 public constant BLOCK_TO_SLOT_DIFF = 10797349; // Mainnet
  address public constant BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

  /// @dev Proof that a validator is owned 
  function verifyValidator(
    bytes32[] calldata validatorProof,
    SSZ.Validator calldata validator,
    uint256 gIndex,
    uint64 ts,
    address sender
  ) public view returns(bool) {
    bytes32 validatorRoot = SSZ.validatorHashTreeRoot(validator);
    bytes32 blockRoot = getParentBlockRoot(ts);
    address caller = withdrawalToAddress(validator.withdrawalCredentials);

    bytes32 root = Merkle.calculateMerkleRoot(validatorProof, validatorRoot, gIndex);
    if(root != blockRoot) revert InvalidProof();
    if(caller != sender) revert UnauthorizedCaller();
    if(!isActiveValidator(validator)) revert InactiveValidator();
    
    return true;  
  }

  /// @dev Proof that a validator changed his FEE_RECIPIENT by proposing a block 
  function verifyFeeRecipient(
    uint256[] calldata indices,
    bytes32[] calldata proof,
    uint256 validatorIndex,
    address feeRecipient,
    uint64 timestamp,
    uint64 parentTs
  ) external returns(bool) {
    if(indices.length != 3) revert LengthMismatch();

    // Encode values to little endians
    bytes32[] memory leaves = new bytes32[](3);
    leaves[0] = SSZ.toLittleEndian(validatorIndex);
    leaves[1] = bytes32(uint256(uint160(feeRecipient)) << 96);
    leaves[2] = SSZ.toLittleEndian(timestamp);

    // Calculate root - If verifies, we can use the values
    bytes32 blockRoot = getParentBlockRoot(parentTs);
    bytes32 root = Merkle.calculateMultiMerkleRoot(proof, leaves, indices);
    if(root != blockRoot) revert InvalidProof();

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

}
