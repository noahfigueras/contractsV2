// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IBeaconOracle {
  error RootNotFound();
  error InvalidProof();
  error InvalidIndex();
  error InactiveValidator();
  error UnauthorizedCaller();
  error LengthMismatch();
}
