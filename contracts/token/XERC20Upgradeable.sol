// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ProposedOwnableUpgradeable } from "./ProposedOwnableUpgradeable.sol";

/**
 * @title XERC20Upgradeable
 * @author Connext Labs
 * @notice This is a simple implementation of an xToken to use within Connext. An xToken is a minimal extension to the
 * ERC-20 standard that enables bridging tokens across domains without creating multiple infungible representations of
 * the same underlying asset.
 *
 * To learn more, please see:
 * - EIP:
 * https://github.com/connext/EIPs/blob/master/EIPS/eip-draft_bridged_tokens.md
 * - Guide to whitelist an xtoken on Connext:
 * https://connext.notion.site/Public-xTokens-Setup-Guide-be4e136a6db14191b8d61bd60563ebd0?pvs=4
 *
 * @dev This contract is designed to be upgradeable so as the EIP is finalized, the implementation
 * can be updated to reflect the standard. The current implementation is the minimal interface
 * required to create an xtoken supported by Connext.
 */
contract XERC20Upgradeable is ERC20Upgradeable, ProposedOwnableUpgradeable {
  // reserve a 50 gap for EIP712Upgradeable
  // reserve a 50 gap for NoncesUpgradeable
  // reserve a 50 gap for ERC20PermitUpgradeable
  uint256[150] private __xtokenBaseGap;

  // ======== Events =========
  /**
   * Emitted when bridge is whitelisted
   * @param bridge Address of the bridge being added
   */
  event BridgeAdded(address indexed bridge);

  /**
   * Emitted when bridge is dropped from whitelist
   * @param bridge Address of the bridge being added
   */
  event BridgeRemoved(address indexed bridge);

  // ======== Constants =========

  // ======== Storage =========
  /**
   * @notice The set of whitelisted bridges
   */
  mapping(address => bool) internal _whitelistedBridges;

  // ======== Constructor =========
  constructor() {}

  // ======== Initializer =========

  function initialize(
    address _owner,
    string memory _name,
    string memory _symbol
  ) public initializer {
    __XERC20_init();
    __ERC20_init(_name, _symbol);
    //__ERC20Permit_init(_name);
    __ProposedOwnable_init();

    // Set specified owner
    _setOwner(_owner);
  }

  // TODO call after upgrading to solidity 0.8.19 and integrating ERC20PermitUpgradeable
  function reinitialize() external reinitializer(2) {
    //__ERC20Permit_init(name());
  }

  /**
   * @dev Initializes XERC20 instance
   */
  function __XERC20_init() internal onlyInitializing {
    __XERC20_init_unchained();
  }

  function __XERC20_init_unchained() internal onlyInitializing {}

  // ======== Errors =========
  error XERC20__onlyBridge_notBridge();
  error XERC20__addBridge_alreadyAdded();
  error XERC20__removeBridge_alreadyRemoved();

  // ============ Modifiers ==============
  modifier onlyBridge() {
    if (!_whitelistedBridges[msg.sender]) {
      revert XERC20__onlyBridge_notBridge();
    }
    _;
  }

  // ========= Admin Functions =========
  /**
   * @notice Adds a bridge to the whitelist
   * @param _bridge Address of the bridge to add
   */
  function addBridge(address _bridge) external onlyOwner {
    if (_whitelistedBridges[_bridge]) {
      revert XERC20__addBridge_alreadyAdded();
    }
    emit BridgeAdded(_bridge);
    _whitelistedBridges[_bridge] = true;
  }

  /**
   * @notice Removes a bridge from the whitelist
   * @param _bridge Address of the bridge to remove
   */
  function removeBridge(address _bridge) external onlyOwner {
    if (!_whitelistedBridges[_bridge]) {
      revert XERC20__removeBridge_alreadyRemoved();
    }
    emit BridgeRemoved(_bridge);
    _whitelistedBridges[_bridge] = false;
  }

  // ========= Public Functions =========

  /**
   * @notice Mints tokens for a given address
   * @param _to Address to mint to
   * @param _amount Amount to mint
   */
  function mint(address _to, uint256 _amount) public onlyBridge {
    _mint(_to, _amount);
  }

  /**
   * @notice Mints tokens for a given address
   * @param _from Address to burn from
   * @param _amount Amount to mint
   */
  function burn(address _from, uint256 _amount) public onlyBridge {
    _burn(_from, _amount);
  }

  // ============ Upgrade Gap ============
  uint256[49] private __GAP; // gap for upgrade safety
}
