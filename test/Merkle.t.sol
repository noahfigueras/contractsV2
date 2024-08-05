// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { Merkle } from "../src/libraries/Merkle.sol";
import { Arrays, HashMap } from "../src/libraries/Arrays.sol";
import { SSZ } from "../src/libraries/SSZ.sol";

contract TestMerkle is Test {
  using Arrays for uint256[];
  using HashMap for uint256;

  bytes32[] public proof;
  bytes32[] public leaves;
  uint256[] public indices;

  function test_sszEncodeValues() public {
    uint256 proposer_index = 696862;
    uint256 timestamp = 1718573123;

    assertEq(0x1ea20a0000000000000000000000000000000000000000000000000000000000, SSZ.toLittleEndian(proposer_index)); 
    assertEq(0x43586f6600000000000000000000000000000000000000000000000000000000, SSZ.toLittleEndian(timestamp)); 
  }

  function test_verifyMultiMerkleRootDebug() public {
    leaves = [
      bytes32(hex'06071e0100000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'c832285000000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'f000000000000000000000000000000000000000000000000000000000000000')
    ];
    proof = [
      bytes32(hex'0400000000000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'0000000000000000000000000000000000000000000000000000000000000000')
    ];
    indices = [
      4,
      10,
      6
    ];

    bytes32 blockRoot = 0x0e6074d75566c7ff882679d25801df1edb4d0592dcbec4062552dc3604d9c7b4; 
    assertEq(Merkle.calculateMultiMerkleRoot(proof, leaves, indices), blockRoot);
  }

  function test_verifyMultiMerkleRoot() public {
    uint256 proposer_index = 696862;
    bytes32 fee_recipient = 0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5000000000000000000000000;
    uint256 timestamp = 1718573123;
    indices = [
      9,
      6433,
      6441
    ];
    leaves = [
      SSZ.toLittleEndian(proposer_index),
      fee_recipient,
      SSZ.toLittleEndian(timestamp)
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

    bytes32 blockRoot = bytes32(0xab5835bed4c54a00490293e9935bccec7b248f5db7f9fe2fbfa34481fe80c916);
    assertEq(Merkle.calculateMultiMerkleRoot(proof, leaves, indices), blockRoot);
  }

  function test_helperIndices() public {
    uint256[] memory helperIndices = new uint256[](2);
    uint256[] memory indices = new uint256[](3);
    indices[0] = 4;
    indices[1] = 10;
    indices[2] = 6;
    helperIndices[0] = 11;
    helperIndices[1] = 7;
    assertEq(helperIndices, Merkle.getHelperIndices(indices));
  }

  function test_branchIndices() public {
    Merkle.getBranchIndices(10);
  }

  function test_arrays() public {
    uint256[] memory test = new uint256[](1);
    uint256[] memory cmp = new uint256[](2);
    cmp[0] = 1;
    cmp[1] = 2;
    test[0] = cmp[0];
    assertEq(cmp, test.push(2));
    assertEq(cmp.pop(), test);

    uint256[] memory test2 = new uint256[](2);
    uint256[] memory add = new uint256[](2);
    uint256[] memory cmp2 = new uint256[](4);
    cmp2[0] = 1;
    cmp2[1] = 2;
    cmp2[2] = 3;
    cmp2[3] = 4;
    test2[0] = 1;
    test2[1] = 2;
    add[0] = 3;
    add[1] = 4;
    assertEq(cmp2, test2.concat(add));
  }

  function test_hashMap() public {
    leaves = [
      bytes32(hex'06071e0100000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'c832285000000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'f000000000000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'0400000000000000000000000000000000000000000000000000000000000000'),
      bytes32(hex'0000000000000000000000000000000000000000000000000000000000000000')
    ];
    indices = [
      4,
      10,
      6,
      11,
      7
    ];

    for(uint256 i = 0; i < indices.length; i++) {
      indices[i].set(leaves[i]);
      assertEq(indices[i].get(), leaves[i]);
      assertEq(indices[i].contains(), true);
    }

    assertEq(uint256(12).contains(), false);
    assertEq(uint256(20).contains(), false);
    assertEq(uint256(4).contains(), true);

  }

}
