// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import { ERC721Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { Ownable2StepUpgradeable } from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract veION is Ownable2StepUpgradeable, ERC721Upgradeable {
  error NotMinter();
  mapping (address => bool) bridges public;

  modifier onlyBridge() {
    if (!bridges[msg.sender]) {
      revert NotMinter();
    }
    _;
  }

  function initialize() public initializer {
    __Ownable2Step_init();
    __ERC721_init("veION", "veION");
  }

/**
 * Mints a new token to a user on this chain, designed to be called by a bridge adapter contract in the flow of sending cross-chain
 * @param to 
 * @param tokenId 
 */
  function mint(address to, uint256 tokenId) public onlyBridge {
    _safeMint(to, tokenId);
  }

  /**
   * Burns token on this chain, designed to be called by a bridge adapter contract in the flow of sending cross-chain
   * @param tokenId 
   */
  function burn(uint256 tokenId) public onlyBridge {
    _burn(tokenId);
  }
}
