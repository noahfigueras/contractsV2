// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IBeaconOracle {
  // As defined in phase0/beacon-chain.md:356
  struct BeaconChainValidator {
      bytes pubkey;
      bytes32 withdrawalCredentials;
      uint64 effectiveBalance;
      bool slashed;
      uint64 activationEligibilityEpoch;
      uint64 activationEpoch;
      uint64 exitEpoch;
      uint64 withdrawableEpoch;
  }
  error RootNotFound();
  error InvalidProof();
  error InvalidIndex();
  error InactiveValidator();
  error UnauthorizedCaller();
  error LengthMismatch();
  error InvalidWithdrawalAddr();
  error EmptyPool();
}
