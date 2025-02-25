// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {FlashAccountBase} from "./FlashAccountBase.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CTokenSignatures} from "./common/CTokenSignatures.sol";

contract FlashAccount is FlashAccountBase, CTokenSignatures {
    /**
     * @notice Only for initial testing, the implementation of supported protocols will be moved to the protocol registry
     */
    event Supplied(address indexed token, address indexed lendingProtocol, uint256 amount);
    event Borrowed(address indexed token, address indexed lendingProtocol, uint256 amount);
    event Repaid(address indexed token, address indexed lendingProtocol, uint256 amount);
    event Withdrawn(address indexed token, address indexed lendingProtocol, uint256 amount);

    constructor(IEntryPoint entryPoint_) FlashAccountBase(entryPoint_) {}

    /**
     * Compound v2 related functions
     */

    /**
     * @dev Lend to Compound V2
     */
    function lendToCompoundV2(address cToken, uint256 amount) public onlyAuthorized {
        address underlying = _getUnderlying(cToken);

        // Approve the cToken to spend the underlying asset
        IERC20(underlying).approve(cToken, amount);

        // Mint cTokens
        (bool success,) = cToken.call(abi.encodeWithSelector(CTOKEN_MINT_SELECTOR, amount));
        require(success, "Mint failed");

        emit Supplied(underlying, cToken, amount);
    }

    /**
     * @dev Borrow from Compound V2
     */
    function borrowFromCompoundV2(address cToken, uint256 amount) public onlyAuthorized {
        address underlying = _getUnderlying(cToken);

        // Borrow the underlying asset
        (bool success,) = cToken.call(abi.encodeWithSelector(CTOKEN_BORROW_SELECTOR, amount));
        require(success, "Borrow failed");

        emit Borrowed(underlying, cToken, amount);
    }

    function _getUnderlying(address cToken) internal returns (address) {
        require(cToken != address(0), "invalid cToken");

        (bool success, bytes memory data) = cToken.call(abi.encodeWithSelector(CTOKEN_UNDERLYING_SELECTOR));
        require(success, "Failed to get underlying");
        return abi.decode(data, (address));
    }

    /**
     * End of compound v2 related functions
     */

    /**
     * @dev Explicit flash loan callback functions
     * All of them are locked through the execution lock to prevent access outside
     * of the `execute` functions
     */

    /**
     * Aave simple flash loan
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address,
        bytes calldata params // user params
    ) external requireInExecution returns (bool) {
        // forward execution
        _decodeAndExecute(params);

        return true;
    }

    /**
     * Balancer flash loan
     */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external requireInExecution {
        // execute furhter operations
        _decodeAndExecute(params);
    }

    /**
     * Morpho flash loan
     */
    function onMorphoFlashLoan(uint256 assets, bytes calldata params) external requireInExecution {
        // execute furhter operations
        _decodeAndExecute(params);
    }

    /**
     * Internal function to decode batch calldata
     */
    function _decodeAndExecute(bytes calldata params) internal {
        (
            address[] memory dest, //
            uint256[] memory value,
            bytes[] memory func
        ) = abi.decode(params, (address[], uint256[], bytes[]));
        if (dest.length != func.length || dest.length != value.length) {
            revert ArrayLengthMismatch();
        }
        uint256 length = dest.length;
        for (uint256 i = 0; i < length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }
}
