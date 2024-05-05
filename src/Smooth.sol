// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Smooth is ERC20 {
  address immutable owner;

  constructor() ERC20("SMOOTH", "SMT") {
    owner = msg.sender; 
  }

  function mint(uint256 amount) public {
    require(msg.sender == owner, "Not SmoothlyPool");
    _mint(msg.sender, amount);
  }

  function burn(uint256 amount) public {
    require(msg.sender == owner, "Not SmoothlyPool");
    _burn(msg.sender, amount);
  }

  // TODO: Make this non transferable 
}

