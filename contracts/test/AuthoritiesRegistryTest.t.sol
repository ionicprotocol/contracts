// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";
import "../ionic/AuthoritiesRegistry.sol";
import "./helpers/WithPool.sol";

contract AuthoritiesRegistryTest is WithPool {
  AuthoritiesRegistry registry;

  function afterForkSetUp() internal override {
    registry = AuthoritiesRegistry(ap.getAddress("AuthoritiesRegistry"));
    if (address(registry) == address(0)) {
      address proxyAdmin = address(999);
      AuthoritiesRegistry impl = new AuthoritiesRegistry();
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), proxyAdmin, "");
      registry = AuthoritiesRegistry(address(proxy));
      registry.initialize(address(1023));
    }

    super.setUpWithPool(
      MasterPriceOracle(ap.getAddress("MasterPriceOracle")),
      ERC20Upgradeable(ap.getAddress("wtoken"))
    );

    setUpPool("auth-reg-test", false, 0.1e18, 1.1e18);
  }

  function testRegistry() public fork(POLYGON_MAINNET) {
    PoolRolesAuthority auth;

    vm.prank(address(555));
    vm.expectRevert("Ownable: caller is not the owner");
    auth = registry.createPoolAuthority(address(comptroller));

    vm.prank(registry.owner());
    auth = registry.createPoolAuthority(address(comptroller));

    assertEq(auth.owner(), registry.owner(), "!same owner");
  }

  function testAuthReconfigurePermissions() public fork(POLYGON_MAINNET) {
    vm.prank(registry.owner());
    PoolRolesAuthority auth = registry.createPoolAuthority(address(comptroller));

    vm.prank(address(8283));
    vm.expectRevert("not owner or pool");
    registry.reconfigureAuthority(address(comptroller));

    registry.reconfigureAuthority(address(comptroller));
  }

  function testAuthPermissions() public fork(POLYGON_MAINNET) {
    vm.prank(registry.owner());
    PoolRolesAuthority auth = registry.createPoolAuthority(address(comptroller));

    vm.prank(address(8283));
    vm.expectRevert("UNAUTHORIZED");
    auth.openPoolSupplierCapabilities(comptroller);

    auth.openPoolSupplierCapabilities(comptroller);

    vm.prank(address(8283));
    vm.expectRevert("UNAUTHORIZED");
    auth.closePoolSupplierCapabilities(comptroller);

    auth.closePoolSupplierCapabilities(comptroller);

    vm.prank(address(8283));
    vm.expectRevert("UNAUTHORIZED");
    auth.closePoolBorrowerCapabilities(comptroller);

    auth.closePoolBorrowerCapabilities(comptroller);
  }
}
