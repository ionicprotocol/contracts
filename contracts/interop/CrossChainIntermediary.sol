// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface L2toL2CrossDomainMessenger {
  function sendMessage(uint256 _destination, address _target, bytes calldata _message) external;
}

interface SuperERC20 is IERC20 {
  function sendERC20(address _to, uint256 _amount, uint256 _chainId) external;
}

contract CrossChainIntermediary {
  L2toL2CrossDomainMessenger public immutable messenger;
  mapping (uint256 => address) public chainToTarget;
  error ChainNotRegistered(uint256 chainId);

  constructor(address _messenger) {
    messenger = L2toL2CrossDomainMessenger(_messenger);
  }

  function mintTo(address _to, uint256 _amount, uint256 _chainId, address _fromToken, address _toCToken) external {
    address _target = chainToTarget[_chainId];
    if (_target == address(0)) {
      revert ChainNotRegistered(_chainId);
    }
    IERC20(_fromToken).transferFrom(msg.sender, address(this), _amount);
    SuperERC20(_fromToken).sendERC20(_to, _amount, _chainId);
    messenger.sendMessage(_chainId, _target, abi.encodeWithSignature("mint(address,uint256)", _to, _amount));
  }
}
