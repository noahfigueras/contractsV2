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
    uint256 timestamp = 1718573135;
    indices = [
      9,
      6433,
      13516144640
    ];
    proof = [
      bytes32(hex'2100e00a5e8328e869406e81704e9b865deb92bec1f8c481b971559defe13ea1'),                                                                                                                                 
      bytes32(hex'bb0ada9c599d4699e739723190e517012b7083a3818543cf14f3afeb40bd69cf'),                                                                                                                                 
      bytes32(hex'899dd86d7a83c73204f2c2bf774f27866566571685ffc1c859948403495513e5'),                                                                                                                                 
      bytes32(hex'52d54820f30bfd19cb0151e283d68e907cd6b1efc7b966e3453983d1d4a80007'),                                                                                                                                 
      bytes32(hex'16256c9d6b630afe9a9d132a762548a076af0c2b55e0fef7c3402c6e57750634'),                                                                                                                                 
      bytes32(hex'76cb3999a216232e7b42b3cc0b121e9e20c28074926f3c9b03e5268566f30007'),                                                                                                                                 
      bytes32(hex'38d80dbc33687715594308583defd3bce42aa6fd655abbf2cc254e6a72f7b3a7'),                                                                                                                                 
      bytes32(hex'4d38cfa0707dbcb56e3204469da3d0b21ba9e44c031016771b14b7cc271fa657'),                                                                                                                                 
      bytes32(hex'26846476fd5fc54a5d43385167c95144f2643f533cc85bb9d16b782f8d7db193'),                                                                                                                                 
      bytes32(hex'506d86582d252405b840018792cad2bf1259f1ef5aa5f887e13cb2f0094f51e1'),
      bytes32(hex'ffff0ad7e659772f9534c195c815efc4014ef1e1daed4404c06385d11192e92b'),
      bytes32(hex'6cf04127db05441cd833107a52be852868890e4317e6a02ab47683aa75964220'),
      bytes32(hex'b7d05f875f140027ef5118a2247bbb84ce8f2f0f1123623085daf7960c329f5f'),
      bytes32(hex'df6af5f5bbdb6be9ef8aa618e4bf8073960867171e29676f8b284dea6a08a85e'),
      bytes32(hex'b58d900f5e182e3c50ef74969ea16c7726c549757cc23523c369587da7293784'),
      bytes32(hex'd49a7502ffcfb0340b1d7885688500ca308161a7f96b62df9d083b71fcc8f2bb'),
      bytes32(hex'8fe6b1689256c0d385f42f5bbe2027a22c1996e110ba97c171d3e5948de92beb'),
      bytes32(hex'8d0d63c39ebade8509e0ae3c9c3876fb5fa112be18f905ecacfecb92057603ab'),
      bytes32(hex'95eec8b2e541cad4e91de38385f2e046619f54496c2382cb6cacd5b98c26f5a4'),
      bytes32(hex'f893e908917775b62bff23294dbbe3a1cd8e6cc1c35b4801887b646a6f81f17f'),
      bytes32(hex'fb00000000000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'3a3132f8995d0020d5d8a761a5b014be0786547499bfe3d2d17f4534d479fbd9'),
      bytes32(hex'552f83bef2164ede6e62b9f1c53cde415f057afcafecdd0a69abc6d47a2f4f71'),
      bytes32(hex'6a7ca38129832d10ca730b20c13a6d412607b3baa4015068c1a0022f2078f03e'),
      bytes32(hex'82eab58be968f51f0e05a6e2506361146e17fad78cdddda1e7ccb1ede1f8ecfd'),
      bytes32(hex'3467dc97fe0ed9d2323c8601f5d48373dcc6339de49c5175cb512a06067dc3b7'),
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
        indices, proof, proposer_index, feeRecipient, uint64(timestamp), uint64()
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
