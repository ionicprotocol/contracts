// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./XERC20Upgradeable.sol";

contract IonicToken is XERC20Upgradeable {
  function initialize() public initializer {
    __ERC20_init("Ionic Token", "IONIC");
    //__ERC20Permit_init(_name);
    __ProposedOwnable_init();

    _setOwner(msg.sender);

    _mint(msg.sender, 1e9 * 10**decimals());
  }
}
