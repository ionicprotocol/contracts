// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { BasePriceOracle } from "../../../oracles/BasePriceOracle.sol";
import { ICErc20 } from "../../../compound/CTokenInterfaces.sol";
import { SimplePriceOracle } from "../../../oracles/default/SimplePriceOracle.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { MockRevertPriceOracle } from "../../../oracles/1337/MockRevertPriceOracle.sol";
import { PythPriceOracle } from "../../../oracles/default/PythPriceOracle.sol";
import { ChainlinkPriceOracleV2 } from "../../../oracles/default/ChainlinkPriceOracleV2.sol";
import { AddressesProvider } from "../../../ionic/AddressesProvider.sol";

contract MasterPriceOracleTest is BaseTest {
  MasterPriceOracle mpo;
  SimplePriceOracle mainOracle;
  SimplePriceOracle fallbackOracle;
  MockRevertPriceOracle revertingOracle;
  ICErc20 mockCToken;
  address someAdminAccount = address(94949);

  address deployer = 0x1155b614971f16758C92c4890eD338C9e3ede6b7;
  address multisig = 0x8Fba84867Ba458E7c6E2c024D2DE3d0b5C3ea1C2;

  address WETH = 0x4200000000000000000000000000000000000006; // none
  address USDC = 0xd988097fb8612cc24eeC14542bC03424c656005f; // pyth
  address USDT = 0xf0F161fDA2712DB8b566946122a5af183995e2eD; // pyth
  address WBTC = 0xcDd475325D6F564d27247D1DddBb0DAc6fA0a5CF; // pyth
  address M_BTC = 0x59889b7021243dB5B1e065385F918316cD90D46c; // pyth
  address ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5; // red
  address weETH_mode = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A; // red
  address STONE = 0x80137510979822322193FC997d400D5A6C747bf7; // red
  address weETH_OLD = 0x028227c4dd1e5419d11Bb6fa6e661920c519D4F5; // red
  address wrsETH = 0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd; // red

  address ionezETH = 0x59e710215d45F584f44c0FEe83DA6d43D762D857;
  address ionWETH = 0x71ef7EDa2Be775E5A7aa8afD02C45F059833e9d2;
  address ionUSDC = 0x2BE717340023C9e14C1Bb12cb3ecBcfd3c3fB038;
  address ionUSDT = 0x94812F2eEa03A49869f95e1b5868C6f3206ee3D3;
  address ionWBTC = 0xd70254C3baD29504789714A7c69d60Ec1127375C;
  address ionSTONE = 0x959FA710CCBb22c7Ce1e59Da82A247e686629310;
  address ionwrsETH = 0x49950319aBE7CE5c3A6C90698381b45989C99b46;
  address ionweETH_mode = 0xA0D844742B4abbbc43d8931a6Edb00C56325aA18;
  address ionweETH_OLD = 0x9a9072302B775FfBd3Db79a7766E75Cf82bcaC0A;
  address ionM_BTC = 0x19F245782b1258cf3e11Eda25784A378cC18c108;

  address redstoneAdapterPriceOracle = 0x63A1531a06F0Ac597a0DfA5A516a37073c3E1e0a;
  address redstoneAdapterPriceOracleWeETH = 0x9c0819E3235c8fF74e79f0caBb51ec477603DE78;

  struct AssetPrices {
    uint256 ezETH;
    uint256 WETH;
    uint256 USDC;
    uint256 USDT;
    uint256 WBTC;
    uint256 STONE;
    uint256 wrsETH;
    uint256 weETH_mode;
    uint256 weETH_OLD;
    uint256 M_BTC;
    uint256 ion_ezETH;
    uint256 ion_WETH;
    uint256 ion_USDC;
    uint256 ion_USDT;
    uint256 ion_WBTC;
    uint256 ion_STONE;
    uint256 ion_wrsETH;
    uint256 ion_weETH_mode;
    uint256 ion_weETH_OLD;
    uint256 ion_M_BTC;
  }

  struct Vars {
    MasterPriceOracle newMpoImpl;
    ChainlinkPriceOracleV2 chainklinkOracleImpl;
    address nativeTokenUSDChainlinkFeed;
    TransparentUpgradeableProxy chainklinkOracleProxy;
    ChainlinkPriceOracleV2 chainlinkPriceOracleV2;
    address[] underlyings;
    address[] fallbackUnderlyings;
    address[] feeds;
    BasePriceOracle[] oracles;
    BasePriceOracle[] fallbackOracles;
    AddressesProvider ap;
  }

  function afterForkSetUp() internal override {
    MasterPriceOracle newMpo = new MasterPriceOracle();
    SimplePriceOracle defaultOracle = new SimplePriceOracle();

    address[] memory underlyings = new address[](0);
    BasePriceOracle[] memory oracles = new BasePriceOracle[](0);

    vm.prank(someAdminAccount);
    newMpo.initialize(underlyings, oracles, defaultOracle, someAdminAccount, true, address(0));

    mpo = newMpo;

    SimplePriceOracle impl = new SimplePriceOracle();
    vm.prank(address(someAdminAccount));
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(impl),
      address(dpa),
      abi.encodePacked(impl.initialize.selector)
    );
    mainOracle = SimplePriceOracle(address(proxy));

    SimplePriceOracle fallbackImpl = new SimplePriceOracle();
    vm.prank(address(someAdminAccount));
    TransparentUpgradeableProxy fallbackProxy = new TransparentUpgradeableProxy(
      address(fallbackImpl),
      address(dpa),
      abi.encodePacked(impl.initialize.selector)
    );
    fallbackOracle = SimplePriceOracle(address(fallbackProxy));

    vm.startPrank(someAdminAccount);
    mainOracle.setDirectPrice(ezETH, 2000);
    fallbackOracle.setDirectPrice(ezETH, 2000);
    vm.stopPrank();

    address[] memory tokens = new address[](1);
    tokens[0] = ezETH;

    BasePriceOracle[] memory oraclesToAdd = new BasePriceOracle[](1);
    oraclesToAdd[0] = BasePriceOracle(mainOracle);
    BasePriceOracle[] memory fallbackOraclesToAdd = new BasePriceOracle[](1);
    fallbackOraclesToAdd[0] = BasePriceOracle(fallbackOracle);

    vm.startPrank(someAdminAccount);
    mpo.add(tokens, oraclesToAdd);
    mpo.addFallbacks(tokens, fallbackOraclesToAdd);
    vm.stopPrank();

    revertingOracle = new MockRevertPriceOracle();
  }

  function testUpgradeMPO() public debuggingOnly forkAtBlock(MODE_MAINNET, 9232262) {
    address mpoAddress = 0x2BAF3A2B667A5027a83101d218A9e8B73577F117;
    MasterPriceOracle mpoExisting = MasterPriceOracle(mpoAddress);
    AssetPrices memory prices;
    AssetPrices memory afterPrices;
    Vars memory vars;

    prices.ezETH = mpoExisting.price(ezETH); // ezETH
    prices.WETH = mpoExisting.price(WETH); // WETH
    prices.USDC = mpoExisting.price(USDC); // USDC
    prices.USDT = mpoExisting.price(USDT); // USDT
    prices.WBTC = mpoExisting.price(WBTC); // WBTC
    prices.STONE = mpoExisting.price(STONE); // STONE
    prices.wrsETH = mpoExisting.price(wrsETH); // wrsETH
    prices.weETH_mode = mpoExisting.price(weETH_mode); // weETH_mode
    prices.weETH_OLD = mpoExisting.price(weETH_OLD); // weETH_OLD
    prices.M_BTC = mpoExisting.price(M_BTC); // M_BTC

    prices.ion_ezETH = mpoExisting.getUnderlyingPrice(ICErc20(ionezETH)); // ionezETH
    prices.ion_WETH = mpoExisting.getUnderlyingPrice(ICErc20(ionWETH)); // ionWETH
    prices.ion_USDC = mpoExisting.getUnderlyingPrice(ICErc20(ionUSDC)); // ionUSDC
    prices.ion_USDT = mpoExisting.getUnderlyingPrice(ICErc20(ionUSDT)); // ionUSDT
    prices.ion_WBTC = mpoExisting.getUnderlyingPrice(ICErc20(ionWBTC)); // ionWBTC
    prices.ion_STONE = mpoExisting.getUnderlyingPrice(ICErc20(ionSTONE)); // ionSTONE
    prices.ion_wrsETH = mpoExisting.getUnderlyingPrice(ICErc20(ionwrsETH)); // ionwrsETH
    prices.ion_weETH_mode = mpoExisting.getUnderlyingPrice(ICErc20(ionweETH_mode)); // ionweETH_mode
    prices.ion_weETH_OLD = mpoExisting.getUnderlyingPrice(ICErc20(ionweETH_OLD)); // ionweETH_OLD
    prices.ion_M_BTC = mpoExisting.getUnderlyingPrice(ICErc20(ionM_BTC)); // ionM_BTC

    emit log_named_address("Proxy Admin", address(dpa));

    emit log_named_address(
      "Current Implementation",
      dpa.getProxyImplementation(TransparentUpgradeableProxy(payable(mpoAddress)))
    );

    vm.startPrank(multisig);

    // Deploys Chainlink Oracle
    vars.chainklinkOracleImpl = ChainlinkPriceOracleV2(0xACea9bfBD6A1DA56a27bada1a8D0e5bb35bFF4E7);
    vars.nativeTokenUSDChainlinkFeed = 0xa47Fd122b11CdD7aad7c3e8B740FB91D83Ce43D1;
    vars.chainklinkOracleProxy = TransparentUpgradeableProxy(payable(0xACea9bfBD6A1DA56a27bada1a8D0e5bb35bFF4E7));

    // Sets Price Feeds On Chainlink Oracle
    vars.chainlinkPriceOracleV2 = ChainlinkPriceOracleV2(address(vars.chainklinkOracleProxy));
    vars.underlyings = new address[](2);
    vars.feeds = new address[](2);
    vars.underlyings[0] = ezETH;
    vars.underlyings[1] = weETH_mode;
    vars.feeds[0] = 0x85baF4a3d1494576d0941a146E24a8690Efa87D5;
    vars.feeds[1] = 0x95a02CBb3f19D88b228858A48cFade87fd337c22;
    vars.chainlinkPriceOracleV2.setPriceFeeds(
      vars.underlyings,
      vars.feeds,
      ChainlinkPriceOracleV2.FeedBaseCurrency.ETH
    );

    // Switches asset oracles for redstone assets ezETH and weETH
    vars.oracles = new BasePriceOracle[](2);
    vars.oracles[0] = BasePriceOracle(vars.chainlinkPriceOracleV2);
    vars.oracles[1] = BasePriceOracle(vars.chainlinkPriceOracleV2);
    mpoExisting.add(vars.underlyings, vars.oracles);

    // Adds fallbacks
    vars.fallbackUnderlyings = new address[](6);
    vars.fallbackUnderlyings[0] = USDC;
    vars.fallbackUnderlyings[1] = USDT;
    vars.fallbackUnderlyings[2] = WBTC;
    vars.fallbackUnderlyings[3] = M_BTC;
    vars.fallbackUnderlyings[4] = ezETH;
    vars.fallbackUnderlyings[5] = weETH_mode;

    vars.fallbackOracles = new BasePriceOracle[](6);
    vars.fallbackOracles[0] = BasePriceOracle(redstoneAdapterPriceOracle);
    vars.fallbackOracles[1] = BasePriceOracle(redstoneAdapterPriceOracle);
    vars.fallbackOracles[2] = BasePriceOracle(redstoneAdapterPriceOracle);
    vars.fallbackOracles[3] = BasePriceOracle(redstoneAdapterPriceOracle);
    vars.fallbackOracles[4] = BasePriceOracle(redstoneAdapterPriceOracle);
    vars.fallbackOracles[5] = BasePriceOracle(redstoneAdapterPriceOracleWeETH);

    mpoExisting.addFallbacks(vars.fallbackUnderlyings, vars.fallbackOracles);

    vm.stopPrank();

    vm.startPrank(deployer);
    // Sets Address on AP
    vars.ap = AddressesProvider(0xb0033576a9E444Dd801d5B69e1b63DBC459A6115);
    vars.ap.setAddress("ChainlinkPriceOracleV2", address(vars.chainlinkPriceOracleV2));
    vm.stopPrank();

    emit log_named_address(
      "New Implementation",
      dpa.getProxyImplementation(TransparentUpgradeableProxy(payable(mpoAddress)))
    );

    afterPrices.ezETH = mpoExisting.price(ezETH); // afterEzETH
    afterPrices.WETH = mpoExisting.price(WETH); // afterWETH
    afterPrices.USDC = mpoExisting.price(USDC); // afterUSDC
    afterPrices.USDT = mpoExisting.price(USDT); // afterUSDT
    afterPrices.WBTC = mpoExisting.price(WBTC); // afterWBTC
    afterPrices.STONE = mpoExisting.price(STONE); // afterSTONE
    afterPrices.wrsETH = mpoExisting.price(wrsETH); // afterWrsETH
    afterPrices.weETH_mode = mpoExisting.price(weETH_mode); // afterWeETH_mode
    afterPrices.weETH_OLD = mpoExisting.price(weETH_OLD); // afterWeETH_OLD
    afterPrices.M_BTC = mpoExisting.price(M_BTC); // afterM_BTC

    afterPrices.ion_ezETH = mpoExisting.getUnderlyingPrice(ICErc20(ionezETH)); // afterIon_ezETH
    afterPrices.ion_WETH = mpoExisting.getUnderlyingPrice(ICErc20(ionWETH)); // afterIon_WETH
    afterPrices.ion_USDC = mpoExisting.getUnderlyingPrice(ICErc20(ionUSDC)); // afterIon_USDC
    afterPrices.ion_USDT = mpoExisting.getUnderlyingPrice(ICErc20(ionUSDT)); // afterIon_USDT
    afterPrices.ion_WBTC = mpoExisting.getUnderlyingPrice(ICErc20(ionWBTC)); // afterIon_WBTC
    afterPrices.ion_STONE = mpoExisting.getUnderlyingPrice(ICErc20(ionSTONE)); // afterIon_STONE
    afterPrices.ion_wrsETH = mpoExisting.getUnderlyingPrice(ICErc20(ionwrsETH)); // afterIon_wrsETH
    afterPrices.ion_weETH_mode = mpoExisting.getUnderlyingPrice(ICErc20(ionweETH_mode)); // afterIon_weETH_mode
    afterPrices.ion_weETH_OLD = mpoExisting.getUnderlyingPrice(ICErc20(ionweETH_OLD)); // afterIon_weETH_OLD
    afterPrices.ion_M_BTC = mpoExisting.getUnderlyingPrice(ICErc20(ionM_BTC)); // afterIon_M_BTC

    assertApproxEqAbs(prices.ezETH, afterPrices.ezETH, (prices.ezETH * 2) / 100, "ezETH price mismatch");
    assertApproxEqAbs(prices.WETH, afterPrices.WETH, (prices.WETH * 2) / 100, "WETH price mismatch");
    assertApproxEqAbs(prices.USDC, afterPrices.USDC, (prices.USDC * 2) / 100, "USDC price mismatch");
    assertApproxEqAbs(prices.USDT, afterPrices.USDT, (prices.USDT * 2) / 100, "USDT price mismatch");
    assertApproxEqAbs(prices.WBTC, afterPrices.WBTC, (prices.WBTC * 2) / 100, "WBTC price mismatch");
    assertApproxEqAbs(prices.STONE, afterPrices.STONE, (prices.STONE * 2) / 100, "STONE price mismatch");
    assertApproxEqAbs(prices.wrsETH, afterPrices.wrsETH, (prices.wrsETH * 2) / 100, "wrsETH price mismatch");
    assertApproxEqAbs(prices.weETH_mode, afterPrices.weETH_mode, (prices.weETH_mode * 2) / 100, "weETH_mode price mismatch");
    assertApproxEqAbs(prices.weETH_OLD, afterPrices.weETH_OLD, (prices.weETH_OLD * 2) / 100, "weETH_OLD price mismatch");
    assertApproxEqAbs(prices.M_BTC, afterPrices.M_BTC, (prices.M_BTC * 2) / 100, "M_BTC price mismatch");

    assertApproxEqAbs(prices.ion_ezETH, afterPrices.ion_ezETH, (prices.ion_ezETH * 2) / 100, "ion_ezETH price mismatch");
    assertApproxEqAbs(prices.ion_WETH, afterPrices.ion_WETH, (prices.ion_WETH * 2) / 100, "ion_WETH price mismatch");
    assertApproxEqAbs(prices.ion_USDC, afterPrices.ion_USDC, (prices.ion_USDC * 2) / 100, "ion_USDC price mismatch");
    assertApproxEqAbs(prices.ion_USDT, afterPrices.ion_USDT, (prices.ion_USDT * 2) / 100, "ion_USDT price mismatch");
    assertApproxEqAbs(prices.ion_WBTC, afterPrices.ion_WBTC, (prices.ion_WBTC * 2) / 100, "ion_WBTC price mismatch");
    assertApproxEqAbs(prices.ion_STONE, afterPrices.ion_STONE, (prices.ion_STONE * 2) / 100, "ion_STONE price mismatch");
    assertApproxEqAbs(prices.ion_wrsETH, afterPrices.ion_wrsETH, (prices.ion_wrsETH * 2) / 100, "ion_wrsETH price mismatch");
    assertApproxEqAbs(prices.ion_weETH_mode, afterPrices.ion_weETH_mode, (prices.ion_weETH_mode * 2) / 100, "ion_weETH_mode price mismatch");
    assertApproxEqAbs(prices.ion_weETH_OLD, afterPrices.ion_weETH_OLD, (prices.ion_weETH_OLD * 2) / 100, "ion_weETH_OLD price mismatch");
    assertApproxEqAbs(prices.ion_M_BTC, afterPrices.ion_M_BTC, (prices.ion_M_BTC * 2) / 100, "ion_M_BTC price mismatch");

    emit log_named_uint("afterPrices.ezETH", afterPrices.ezETH);
    emit log_named_uint("afterPrices.ion_ezETH", afterPrices.ion_ezETH);
    emit log_named_uint("afterPrices.WETH", afterPrices.WETH);
    emit log_named_uint("afterPrices.ion_WETH", afterPrices.ion_WETH);
    emit log_named_uint("afterPrices.USDC", afterPrices.USDC);
    emit log_named_uint("afterPrices.ion_USDC", afterPrices.ion_USDC);
    emit log_named_uint("afterPrices.USDT", afterPrices.USDT);
    emit log_named_uint("afterPrices.ion_USDT", afterPrices.ion_USDT);
    emit log_named_uint("afterPrices.WBTC", afterPrices.WBTC);
    emit log_named_uint("afterPrices.ion_WBTC", afterPrices.ion_WBTC);
    emit log_named_uint("afterPrices.STONE", afterPrices.STONE);
    emit log_named_uint("afterPrices.ion_STONE", afterPrices.ion_STONE);
    emit log_named_uint("afterPrices.wrsETH", afterPrices.wrsETH);
    emit log_named_uint("afterPrices.ion_wrsETH", afterPrices.ion_wrsETH);
    emit log_named_uint("afterPrices.weETH_mode", afterPrices.weETH_mode);
    emit log_named_uint("afterPrices.ion_weETH_mode", afterPrices.ion_weETH_mode);
    emit log_named_uint("afterPrices.weETH_OLD", afterPrices.weETH_OLD);
    emit log_named_uint("afterPrices.ion_weETH_OLD", afterPrices.ion_weETH_OLD);
    emit log_named_uint("afterPrices.M_BTC", afterPrices.M_BTC);
    emit log_named_uint("afterPrices.ion_M_BTC", afterPrices.ion_M_BTC);
  }

  function testGetUnderlyingPrice() public fork(MODE_MAINNET) {
    vm.prank(someAdminAccount);
    uint256 price = mpo.getUnderlyingPrice(ICErc20(ionezETH));
    assertEq(price, 2000, "Price should match the mock price");
  }

  function testGetUnderlyingPriceWhenZero() public fork(MODE_MAINNET) {
    vm.prank(someAdminAccount);
    mainOracle.setDirectPrice(ezETH, 0);
    uint256 price = mpo.getUnderlyingPrice(ICErc20(ionezETH));
    assertEq(price, 2000, "Price should match the mock price");
  }

  function testGetUnderlyingPriceWhenZeroAddressOracle() public fork(MODE_MAINNET) {
    address[] memory tokens = new address[](1);
    tokens[0] = ezETH;

    BasePriceOracle[] memory oraclesToAdd = new BasePriceOracle[](1);
    oraclesToAdd[0] = BasePriceOracle(0x0000000000000000000000000000000000000000);

    vm.prank(someAdminAccount);
    mpo.add(tokens, oraclesToAdd);

    uint256 price = mpo.getUnderlyingPrice(ICErc20(ionezETH));
    assertEq(price, 2000, "Price should match the mock price");
  }

  function testGetUnderlyingPriceWhenOracleReverts() public fork(MODE_MAINNET) {
    address[] memory tokens = new address[](1);
    tokens[0] = ezETH;

    BasePriceOracle[] memory oraclesToAdd = new BasePriceOracle[](1);
    oraclesToAdd[0] = BasePriceOracle(revertingOracle);

    vm.prank(someAdminAccount);
    mpo.add(tokens, oraclesToAdd);

    uint256 price = mpo.getUnderlyingPrice(ICErc20(ionezETH));
    assertEq(price, 2000, "Price should match the mock price");
  }

  function testPrice() public fork(MODE_MAINNET) {
    vm.prank(someAdminAccount);
    uint256 price = mpo.price(ezETH);
    assertEq(price, 2000, "Price should match the mock price");
  }

  function testPriceWhenZero() public fork(MODE_MAINNET) {
    vm.prank(someAdminAccount);
    mainOracle.setDirectPrice(ezETH, 0);
    uint256 price = mpo.price(ezETH);
    assertEq(price, 2000, "Price should match the mock price");
  }

  function testPriceWhenZeroAddressOracle() public fork(MODE_MAINNET) {
    address[] memory tokens = new address[](1);
    tokens[0] = ezETH;

    BasePriceOracle[] memory oraclesToAdd = new BasePriceOracle[](1);
    oraclesToAdd[0] = BasePriceOracle(0x0000000000000000000000000000000000000000);

    vm.prank(someAdminAccount);
    mpo.add(tokens, oraclesToAdd);

    uint256 price = mpo.price(ezETH);
    assertEq(price, 2000, "Price should match the mock price");
  }

  function testPriceWhenOracleReverts() public fork(MODE_MAINNET) {
    address[] memory tokens = new address[](1);
    tokens[0] = ezETH;

    BasePriceOracle[] memory oraclesToAdd = new BasePriceOracle[](1);
    oraclesToAdd[0] = BasePriceOracle(revertingOracle);

    vm.prank(someAdminAccount);
    mpo.add(tokens, oraclesToAdd);

    uint256 price = mpo.price(ezETH);
    assertEq(price, 2000, "Price should match the mock price");
  }
}
