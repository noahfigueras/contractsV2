// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { BeaconOracle } from "../src/BeaconOracle.sol";
import { IBeaconOracle } from "../src/interfaces/IBeaconOracle.sol";

import { SSZ } from "../src/libraries/SSZ.sol";
import { Merkle } from "../src/libraries/Merkle.sol";

contract TestBeaconOracle is Test, IBeaconOracle {
  using stdJson for string;

  string FORK_URL = vm.envString("MAINNET_FORK");
  uint256 fork;

  BeaconOracle public oracle;

  struct feeRecipientProofJSON {
    bytes32[] proof;
    uint256[] indices;
    uint64 validatorIndex;
    address feeRecipient;
    uint64 timestamp;
  }

  struct registrationProofJSON {
    bytes32[] validatorProof;
    SSZ.Validator validator;
    uint64 validatorIndex;
    bytes32 blockRoot;
    uint256 gIndex;
    uint64 timestamp;
  }

  bytes32[] public proof;
  uint256[] public indices;

  registrationProofJSON public registrationProof;
  feeRecipientProofJSON public feeRecipientProof;

  function setUp() public {
    string memory root = vm.projectRoot();
    string memory path = string.concat(root, "/test/fixtures/validator_registration.json");
    string memory path2 = string.concat(root, "/test/fixtures/fee_recipient_slash.json");
    string memory json = vm.readFile(path);
    bytes memory data = json.parseRaw("$");
    string memory json2 = vm.readFile(path2);
    bytes memory data2 = json2.parseRaw("$");
    registrationProof = abi.decode(data, (registrationProofJSON));
    feeRecipientProof = abi.decode(data2, (feeRecipientProofJSON));
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
    bytes32 root = Merkle.calculateMerkleRoot(proof, leaf, 11);
    bytes32 root2 = Merkle.calculateMerkleRoot(
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
      registrationProof.timestamp,
      msg.sender
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
      registrationProof.timestamp,
      msg.sender
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
      1000000,
      msg.sender
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
      registrationProof.timestamp,
      msg.sender
    );
  }

  function test_FeeRecipientChange() public {
    // Better tests in integretion-tests
    uint256 proposer_index = 696862;
    address feeRecipient = 0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5; 
    uint256 timestamp = 1718573123;
    indices = [
      9,
      6433,
      6441
    ];
    proof = [
      bytes32(hex'b316900100000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'552f83bef2164ede6e62b9f1c53cde415f057afcafecdd0a69abc6d47a2f4f71'),
      bytes32(hex'83a5208b589808cf93679e7bbb1e0d668c73995a9b6db86db802aca040d7ed19'),
      bytes32(hex'82eab58be968f51f0e05a6e2506361146e17fad78cdddda1e7ccb1ede1f8ecfd'),
      bytes32(hex'd8e4e01c2de60def1ed22fbf69cd77dadd2cddbc0d86644f7041b95a06b1d0c4'),
      bytes32(hex'91eea28200b4f7e7f39e195e9bfa4406c388b038e7b1d793466f30c783a468d0'),
      bytes32(hex'5842e447dc6a52c921c292f1c06fbf98fc39e123d0ea592b9fd98759eb01f28f'),
      bytes32(hex'71a6d6c6e7661c2db605750a399568a4cd7d224bada2f90e4139add65329445f'),
      bytes32(hex'b46f0c01805fe212e15907981b757e6c496b0cb06664224655613dcec82505bb'),
      bytes32(hex'db56114e00fdd4c1f85c892bf35ac9a89289aaecb1ebd0a96cde606a748b5d71'),
      bytes32(hex'5adf3630e082725d52ef90c24257302c20fbfb3c686b9dc9d89fd9eff8d0e345'),
      bytes32(hex'0000000000000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'a9188e0000000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b'),
      bytes32(hex'ecaf4123f2be7f1f7b7eacf63997326dbed3ef925959daaaf9ae2c1d911c88ec')
    ];

    vm.selectFork(fork);
    vm.rollFork(20107024); // One over 20107023 (verifying block)
    bytes32 blockRoot = bytes32(0xab5835bed4c54a00490293e9935bccec7b248f5db7f9fe2fbfa34481fe80c916);
    oracle = new BeaconOracle();
    assertEq(
      oracle.verifyFeeRecipient(
        indices, proof, proposer_index, feeRecipient, uint64(1718573135)
    ), true);
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
