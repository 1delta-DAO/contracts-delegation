// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "contracts/1delta/flash-account/FlashAccountErc7579.sol";

contract DeployFlashAccountScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PK");

        vm.startBroadcast(deployerPrivateKey);

        FlashAccountErc7579 flashAccount = new FlashAccountErc7579();

        console.log("FlashAccountErc7579 deployed to:", address(flashAccount));

        vm.stopBroadcast();
    }
}
