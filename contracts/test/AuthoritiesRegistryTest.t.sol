// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";
import "../ionic/AuthoritiesRegistry.sol";
import "./helpers/WithPool.sol";
import { RolesAuthority, Authority } from "solmate/auth/authorities/RolesAuthority.sol";

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

  function upgradeRegistry() internal {
    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(registry)));
    AuthoritiesRegistry newImpl = new AuthoritiesRegistry();
    vm.startPrank(dpa.owner());
    dpa.upgradeAndCall(
      proxy,
      address(newImpl),
      abi.encodeWithSelector(AuthoritiesRegistry.reinitialize.selector, registry.leveredPositionsFactory())
    );
    vm.stopPrank();
  }

  function upgradeAuth(PoolRolesAuthority auth) internal {
    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(auth)));
    PoolRolesAuthority newImpl = new PoolRolesAuthority();
    vm.prank(dpa.owner());
    dpa.upgrade(proxy, address(newImpl));
  }

  function testAuthPermissions() public debuggingOnly fork(POLYGON_MAINNET) {
    address pool = 0xbc2889CC2bC2c31943f0A35465527F2c3C3f5984;
    registry = AuthoritiesRegistry(0xc8D8F8a8bB89A7ADD3c9f4FF3b72Ff22D03ad8C6);
    //upgradeRegistry();

    PoolRolesAuthority auth = PoolRolesAuthority(0xB964d419cF9CEcFEfD7f6B7F50d0C67AD3fE787B);
    //upgradeAuth(auth);

    //vm.prank(registry.owner());
    //registry.reconfigureAuthority(pool);

    bool isReg = auth.doesUserHaveRole(address(registry), auth.REGISTRY_ROLE());
    assertEq(isReg, true, "!not registry role");

    bool canCall = auth.canCall(address(registry), address(auth), RolesAuthority.setUserRole.selector);
    assertEq(canCall, true, "!cannot call setUserRol");
  }
}
