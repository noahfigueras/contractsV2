// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { BeaconOracle } from "../src/BeaconOracle.sol";
import { IBeaconOracle } from "../src/interfaces/IBeaconOracle.sol";

import { SSZ } from "../src/SSZ.sol";
import { Merkle } from "../src/Merkle.sol";

contract TestBeaconOracle is Test, IBeaconOracle {
  using stdJson for string;

  string FORK_URL = vm.envString("MAINNET_FORK");
  uint256 fork;

  BeaconOracle public oracle;

  struct registrationProofJSON {
    bytes32[] validatorProof;
    SSZ.Validator validator;
    uint64 validatorIndex;
    bytes32 blockRoot;
    uint256 gIndex;
    uint64 timestamp;
  }
  bytes32[] public proof;
  registrationProofJSON public registrationProof;

  function setUp() public {
    string memory root = vm.projectRoot();
    string memory path = string.concat(root, "/test/fixtures/validator_registration.json");
    string memory json = vm.readFile(path);
    bytes memory data = json.parseRaw("$");
    registrationProof = abi.decode(data, (registrationProofJSON));
    fork = vm.createSelectFork(FORK_URL);
  }

  function test_verifyProof() public {
    vm.selectFork(fork);
    vm.rollFork(19688741); // One over 19683121 (verifying block)
    oracle = new BeaconOracle();
    bytes32 leaf = hex'd361c44b28accf7365cf3731660cddec2f3bd2f27f36253c2f5d7837c6608e5d';
    proof = [
      bytes32(hex'c13266053e2af18a4777f88f1c175c6b65c0fc63ddb21bebe1d59fa290e8c887'),
      bytes32(hex'6e57bd8c3626bd04ef1c0d6e708abf32d4e7ee25ac92c50880b4853191d15fdf'),
      bytes32(hex'4d5b1d0517ca06bd722077e5a396f7774e0de018c411ea1389be948fd5016099')
    ];

    bytes32 validatorRoot = SSZ.validatorHashTreeRoot(registrationProof.validator);
    bytes32 root = oracle.calculate_merkle_root(proof, leaf, 11);
    bytes32 root2 = oracle.calculate_merkle_root(
      registrationProof.validatorProof,
      validatorRoot,
      registrationProof.gIndex 
    );

    assertEq(root, hex'564f8fec0e94f43397efad2c55313a9325922e3cc9b26ed9049d9d1b1c43da4a');
    assertEq(root2, hex'564f8fec0e94f43397efad2c55313a9325922e3cc9b26ed9049d9d1b1c43da4a');
  }

  function test_RegistrationMainnet_UnauthorizedCaller() public {
    vm.selectFork(fork);
    vm.rollFork(19688741); // One over 19683121 (verifying block)
    oracle = new BeaconOracle();

    vm.expectRevert(UnauthorizedCaller.selector);
    oracle.verifyValidator(
      registrationProof.validatorProof,
      registrationProof.validator,
      registrationProof.gIndex,
      registrationProof.timestamp
    );
  }

  function test_RegistrationMainnet_InvalidProof() public {
    vm.selectFork(fork);
    vm.rollFork(19688741); // One over 19683121 (verifying block)
    oracle = new BeaconOracle();

    vm.prank(address(0xbe2C1805CcD7f4Ae97457A6C90dfDD5542364A09));
    vm.expectRevert(InvalidIndex.selector);
    oracle.verifyValidator(
      registrationProof.validatorProof,
      registrationProof.validator,
      100,
      registrationProof.timestamp
    );
  }

  function test_RegistrationMainnet_NoHistoryRoot() public {
    vm.selectFork(fork);
    oracle = new BeaconOracle();
    vm.prank(address(0xbe2C1805CcD7f4Ae97457A6C90dfDD5542364A09));
    vm.expectRevert(RootNotFound.selector);
    oracle.verifyValidator(
      registrationProof.validatorProof,
      registrationProof.validator,
      registrationProof.gIndex,
      1000000 
    );
  }

  function test_RegistrationMainnet() public {
    vm.selectFork(fork);
    vm.rollFork(19688741); // One over 19683121 (verifying block)
    oracle = new BeaconOracle();
    vm.prank(address(0xbe2C1805CcD7f4Ae97457A6C90dfDD5542364A09));
    oracle.verifyValidator(
      registrationProof.validatorProof,
      registrationProof.validator,
      registrationProof.gIndex,
      registrationProof.timestamp
    );
  }

  function test_isActiveValidator() public {
    oracle = new BeaconOracle();
    assertEq(true, oracle.isActiveValidator(registrationProof.validator));
  }

  function test_isActiveValidator_Inactive() public {
    oracle = new BeaconOracle();
    // TODO: Test exited validator 197823
    //assertEq(false, pool.isActiveValidator(v));
  }
}
