// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface ISmoothlyPoolV2 {
  event Registered(
    uint64 indexed validatorIndex,
    uint256 effectiveBalance,
    address withdrawal
  );
  event Received(
    address indexed sender,
    uint256 value
  );
  error CorrectFeeRecipient();
  error NotOwner();
  error Unregistered();
  error AlreadyRegistered();
  error WithdrawalsDisabled();
  error TimelockNotReached();
  error BondTooLow();
  error InvalidBlockTimestamp();
}
