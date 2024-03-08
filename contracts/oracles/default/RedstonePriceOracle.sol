// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../BasePriceOracle.sol";
import { SafeOwnableUpgradeable } from "../../ionic/SafeOwnableUpgradeable.sol";

/**
 * @title RedstonePriceOracle
 * @notice Returns prices from Redstone.
 * @dev Implements `BasePriceOracle`.
 * @author Veliko Minkov <v.minkov@dcvx.io> (https://github.com/vminkov)
 */
contract RedstonePriceOracle is SafeOwnableUpgradeable, BasePriceOracle {
  /**
   * @notice Redstone NATIVE/USD price feed contracts.
   */
  address public NATIVE_TOKEN_USD_PRICE_FEED;

  /**
   * @notice The USD Token of the chain
   */
  address public USD_TOKEN;

  /**
   * @notice The address of the Redstone oracle on Mode network
   */
  address public constant REDSTONE_ORACLE_ADDRESS = 0x7C1DAAE7BB0688C9bfE3A918A4224041c7177256;

  /**
   * @dev Constructor to set admin, wtoken address and native token USD price feed address
   * @param _usdToken The Wrapped native asset address
   * @param nativeTokenUsdFeed Will this oracle return prices denominated in USD or in the native token.
   */
  function initialize(address _usdToken, address nativeTokenUsdFeed) public initializer {
    __SafeOwnable_init(msg.sender);
    USD_TOKEN = _usdToken;
    NATIVE_TOKEN_USD_PRICE_FEED = nativeTokenUsdFeed;
  }

  /**
   * @notice Internal function returning the price in of `underlying`.
   * @dev will return a price denominated in the native token
   */
  function _price(address underlying) internal view returns (uint256) {
    return 0;
  }

  /**
   * @notice Returns the price in of `underlying` either in the
   * native token (implements `BasePriceOracle`).
   */
  function price(address underlying) external view override returns (uint256) {
    return _price(underlying);
  }

  /**
   * @notice Returns the price in WNATIVE of the token underlying `cToken`.
   * @dev Implements the `BasePriceOracle` interface for Ionic pools (and Compound v2).
   * @return Price in WNATIVE of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
   */
  function getUnderlyingPrice(ICErc20 cToken) external view override returns (uint256) {
    // Get underlying token address
    address underlying = cToken.underlying();

    uint256 oraclePrice = _price(underlying);

    uint256 underlyingDecimals = uint256(ERC20Upgradeable(underlying).decimals());
    return
      underlyingDecimals <= 18
        ? uint256(oraclePrice) * (10**(18 - underlyingDecimals))
        : uint256(oraclePrice) / (10**(underlyingDecimals - 18));
  }
}
