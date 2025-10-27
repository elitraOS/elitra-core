// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { ElitraVault } from "src/ElitraVault.sol";

import { console } from "forge-std/console.sol";

import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { BaseScript } from "./Base.s.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract Upgrade is BaseScript {
    using Address for address;

    function run(address _proxy, address _newImpl) public broadcast {
        bytes memory upgradeCalldata = abi.encodeWithSelector(ProxyAdmin.upgradeAndCall.selector, _proxy, _newImpl, "");
        console.logBytes(upgradeCalldata);
    }
}
