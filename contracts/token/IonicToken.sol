// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./XERC20Upgradeable.sol";

contract IonicToken is XERC20Upgradeable {
  function initialize() public initializer {
    __XERC20_init();
    __ERC20_init("Ionic Token", "IONIC");
    //__ERC20Permit_init(_name);
    __ProposedOwnable_init();

    _setOwner(msg.sender);

    uint256 TEN_BILLION = 10e9;
    _mint(msg.sender, TEN_BILLION * 10**decimals());
  }
}
