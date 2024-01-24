//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../src/GrowMiner.sol";
import "../src/GROW.sol";
import "forge-std/Script.sol";

contract MinerDeploy is Script {
    address[] owners;
    IERC20 usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    GrowToken grow = GrowToken(0xA72f53ea4f3Cf19f1F6359E87E58221Bd0a7068b);
    address owner1 = 0xD43f17A3103a07d35215E1b19676f4FbFb6db682;
    address owner2 = 0xccFaBE896671b27F002Da529Ea9b6B8578397124;

    function run() public {
        owners.push(owner1);
        owners.push(owner2);

        vm.startBroadcast();
        GrowMiner miner = new GrowMiner(address(grow), address(usdt), owners);

        console.log("Miner address: %s", address(miner));
        miner.transferOwnership(0xD2EDE3a83E1a5ec192B425b21Bf95AFafab68a60);
        vm.stopBroadcast();
    }
}
