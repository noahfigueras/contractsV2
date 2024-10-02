// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface ISmoothlyPoolV2 {
  event Registered(
    uint64 indexed validatorIndex,
    uint256 effectiveBalance,
    address withdrawal
  );
  event Withdrawal(uint256 indexed validatorIndex, uint256 amount, address to);
  event Exit(uint256 indexed validatorIndex, string reason);
  event Received(address indexed sender, uint256 value);
  event Donated(address indexed sender, uint256 value);

  error CorrectFeeRecipient();
  error UpdateNotSatisfied();
  error NotOwner();
  error Unregistered();
  error AlreadyRegistered();
  error WithdrawalsDisabled();
  error TimelockNotReached();
  error BondNotSatisfied();
  error InvalidBlockTimestamp();
  error UpdateNotAvailable();
}
