// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { BeaconOracle } from "../src/BeaconOracle.sol";

contract ProofHelper is Test, BeaconOracle {

  address public constant SYSTEM_ADDRESS = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;

  event Deployed(address contractAddress);

  struct RegistrationProof {
    bytes32[] proof;
    BeaconChainValidator validator;
    uint64 validatorIndex;
    bytes32 blockRoot;
    uint256 gIndex;
    uint64 timestamp;
  }

  struct WithdrawalProof {
    bytes32[] leaves;
    bytes32[] branches;
    uint256[] indices;
    bytes32 blockRoot;
    uint64 validatorIndex;
    uint64 timestamp;
  }

  function loadRegistrationData() public view returns(RegistrationProof memory _proof) {
    string memory json = vm.readFile("./test/test-data/validator_465789_registration.json");
    _proof.proof = abi.decode(vm.parseJson(json, ".proof"), (bytes32[]));
    _proof.validator.pubkey = abi.decode(vm.parseJson(json, ".validator.pubkey"), (bytes));
    _proof.validator.withdrawalCredentials = abi.decode(vm.parseJson(json, ".validator.withdrawalCredentials"), (bytes32));
    _proof.validator.effectiveBalance = abi.decode(vm.parseJson(json, ".validator.effectiveBalance"), (uint64));
    _proof.validator.slashed = abi.decode(vm.parseJson(json, ".validator.slashed"), (bool));
    _proof.validator.activationEligibilityEpoch = abi.decode(vm.parseJson(json, ".validator.activationEligibilityEpoch"), (uint64));
    _proof.validator.activationEpoch = abi.decode(vm.parseJson(json, ".validator.activationEpoch"), (uint64));
    _proof.validator.exitEpoch = abi.decode(vm.parseJson(json, ".validator.exitEpoch"), (uint64));
    _proof.validator.withdrawableEpoch = abi.decode(vm.parseJson(json, ".validator.withdrawableEpoch"), (uint64));
    _proof.validatorIndex = abi.decode(vm.parseJson(json, ".validatorIndex"), (uint64));
    _proof.blockRoot = abi.decode(vm.parseJson(json, ".blockRoot"), (bytes32));
    _proof.gIndex = abi.decode(vm.parseJson(json, ".gI"), (uint256));
    _proof.timestamp = abi.decode(vm.parseJson(json, ".timestamp"), (uint64));
  }

  function loadWithdrawalData() public view returns(WithdrawalProof memory _proof) {
    string memory json = vm.readFile("./test/test-data/validator_465789_withdrawal.json");
    _proof.leaves = abi.decode(vm.parseJson(json, ".leaves"), (bytes32[]));
    _proof.branches = abi.decode(vm.parseJson(json, ".branches"), (bytes32[]));
    _proof.indices = abi.decode(vm.parseJson(json, ".indices"), (uint256[]));
    _proof.blockRoot = abi.decode(vm.parseJson(json, ".blockRoot"), (bytes32));
    _proof.validatorIndex = abi.decode(vm.parseJson(json, ".validatorIndex"), (uint64));
    _proof.timestamp = abi.decode(vm.parseJson(json, ".timestamp"), (uint64));
  }

  function deployBeaconBlockRootPrecompile() public {
    bytes memory BEACON_ROOT_PRECOMPILE = vm.envBytes("BEACON_ROOT_PRECOMPILE_BYTECODE");
    address BEACON_ROOT_DEPLOYER = vm.envAddress("BEACON_ROOT_DEPLOYER");
    vm.prank(BEACON_ROOT_DEPLOYER);
    deploy(BEACON_ROOT_PRECOMPILE);
    vm.warp(1710338135);
    vm.roll(19426587);
  }

  function setBeaconBlockRoot(bytes32 root) public {
    vm.prank(SYSTEM_ADDRESS);
    (bool success, ) = BEACON_ROOTS.call(abi.encode(root));
    require(success, "Failed to set Beacon Block Root");
  }

  function deploy(bytes memory _bytecode) public returns (address newContractAddress) {
      assembly {
          newContractAddress := create(0, add(_bytecode, 0x20), mload(_bytecode))
          if iszero(newContractAddress) {
              revert(0, 0)
          }
      }

      emit Deployed(newContractAddress);
  }
}
