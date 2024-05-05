// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface ISmoothlyPoolV2 {
  event Registered(
    uint64 indexed validatorIndex,
    uint256 effectiveBalance,
    address withdrawal
  );
}
