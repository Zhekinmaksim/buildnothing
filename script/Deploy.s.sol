// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/BuildNothing.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        BuildNothing bn = new BuildNothing();
        console.log("BuildNothing deployed:", address(bn));
        vm.stopBroadcast();
    }
}
