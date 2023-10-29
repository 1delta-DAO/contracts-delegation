// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {WithStorageComet} from "../../storage/CometBrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @title AAVE management contract
 * @notice allows the management of AAVE V3 protocol data
 * @author Achthar
 */
contract CometManagementModule is WithStorageComet {
    modifier onlyManagement() {
        require(ms().isManager[msg.sender], "Only management can interact.");
        _;
    }

    // STATE SETTERS

    function addComet(address _comet, uint8 _id) external onlyManagement {
        cos().comet[_id] = _comet;
    }

    function setUniswapRouter(address _router) external onlyManagement {
        us().swapRouter = _router;
    }

    function setNativeWrapper(address _nativeWrapper) external onlyManagement {
        us().weth = _nativeWrapper;
    }

    function approveRouter(address[] memory assets) external onlyManagement {
        address router = us().swapRouter;
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(router, type(uint256).max);
        }
    }

    function approveComet(address[] memory assets, uint8 _cometId) external onlyManagement {
        address comet = cos().comet[_cometId];
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(comet, type(uint256).max);
        }
    }

    // VIEW FUNCTIONS

    function getFactory() external view returns (address factory) {
        factory = us().v3factory;
    }

    function getSwapRouter() external view returns (address) {
        return us().swapRouter;
    }

    function getNativeWrapper() external view returns (address) {
        return us().weth;
    }

    function getComet(uint8 _id) external view returns (address pool) {
        pool = cos().comet[_id];
    }
}
