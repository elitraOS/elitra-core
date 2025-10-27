// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { ElitraGateway } from "src/ElitraGateway.sol";
import { ElitraRegistry } from "src/ElitraRegistry.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { BaseScript } from "./Base.s.sol";

import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";

contract Deploy is BaseScript {
    function run() public broadcast returns (ElitraGateway gateway, ElitraRegistry registry) {
        ElitraRegistry registryImpl = new ElitraRegistry();
        console.log("Registry implementation address", address(registryImpl));

        bytes memory data =
            abi.encodeWithSelector(ElitraRegistry.initialize.selector, broadcaster, RolesAuthority(address(0)));
        registry = ElitraRegistry(payable(new TransparentUpgradeableProxy(address(registryImpl), broadcaster, data)));

        ElitraGateway gatewayImpl = new ElitraGateway();
        data = abi.encodeWithSelector(ElitraGateway.initialize.selector, address(registry));
        console.log("Gateway implementation address", address(gatewayImpl));
        gateway = ElitraGateway(payable(new TransparentUpgradeableProxy(address(gatewayImpl), broadcaster, data)));

        console.log("Gateway address", address(gateway));
        console.log("Registry address", address(registry));
    }
}
