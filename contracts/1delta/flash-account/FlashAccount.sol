// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {FlashAccountBase} from "./FlashAccountBase.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CTokenSignatures} from "./common/CTokenSignatures.sol";

contract FlashAccount is FlashAccountBase, CTokenSignatures {
    event Supplied(address indexed token, address indexed lendingProtocol, uint256 amount);
    event Borrowed(address indexed token, address indexed lendingProtocol, uint256 amount);
    event Repaid(address indexed token, address indexed lendingProtocol, uint256 amount);
    event Withdrawn(address indexed token, address indexed lendingProtocol, uint256 amount);

    error OnlyOwner();
    /**
     * @notice Only for initial testing, the implementation of supported protocols will be moved to the protocol registry
     */

    mapping(address => address) public cTokens;

    constructor(IEntryPoint entryPoint_) FlashAccountBase(entryPoint_) {}

    /**
     * Compound v2 related functions
     */

    /**
     * @dev Lend to Compound V2
     */
    function lendToCompoundV2(address underlying, uint256 amount) public requireInExecution {
        address cToken = cTokens[underlying];
        require(cToken != address(0), "cToken not set");

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
    function borrowFromCompoundV2(address underlying, uint256 amount) public requireInExecution {
        address cToken = cTokens[underlying];
        require(cToken != address(0), "cToken not set");

        // Borrow the underlying asset
        (bool success,) = cToken.call(abi.encodeWithSelector(CTOKEN_BORROW_SELECTOR, amount));
        require(success, "Borrow failed");

        emit Borrowed(underlying, cToken, amount);
    }

    /**
     * @dev Open a leveraged position using a flash loan
     */
    function openLeveragedPosition(
        address underlying,
        address borrowToken,
        uint256 depositAmount,
        uint256 flashLoanAmount
    ) external requireInExecution {
        require(IERC20(underlying).balanceOf(address(this)) >= depositAmount, "Insufficient balance");

        address aaveV3Pool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

        (bool success, uint128 premium)= aaveV3Pool.call(abi.encodeWithSignature("FLASHLOAN_PREMIUM_TOTAL()");)
        uint256 aavePremium = percentMul(flashLoanAmount, flashLoanPremiumTotal);
        uint256 totalDebt = flashLoanAmount + aavePremium;

        // prepare required calldata 
        address[] memory dests = new address[](1);
        dests[0] = underlying;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", aaveV3Pool, totalDebt);

        bytes memory params = abi.encode(dests, values, calls);


        // Take a flash loan
        _takeFlashLoan(flashLoanProvider, underlying, flashLoanAmount);

        // Add user's deposit
        uint256 totalAmount = depositAmount + flashLoanAmount;

        // Lend to Compound V2
        lendToCompoundV2(underlying, totalAmount);

        // Borrow
        borrowFromCompoundV2(borrowToken, _calculateBorrowAmount(totalAmount));

        // Repay flash loan
        _repayFlashLoan(flashLoanProvider, underlying, flashLoanAmount);
    }

    function _takeFlashLoan(address provider, address asset, uint256 amount) internal {
        // Implement flash loan logic using the provider
    }

    function _repayFlashLoan(address provider, address asset, uint256 amount) internal {
        // Implement flash loan repayment logic
    }

    function _calculateBorrowAmount(uint256 totalAmount) internal pure returns (uint256) {
        // Implement logic to calculate the amount to borrow
        return totalAmount / 2; // Example logic
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

    // MATH
    // Maximum percentage factor (100.00%)
    uint256 internal constant PERCENTAGE_FACTOR = 1e4;

    // Half percentage factor (50.00%)
    uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

    /**
     * @notice Executes a percentage multiplication
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param value The value of which the percentage needs to be calculated
     * @param percentage The percentage of the value to be calculated
     * @return result value percentmul percentage
     */
    function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
        assembly {
            if iszero(or(iszero(percentage), iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage))))) {
                revert(0, 0)
            }

            result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
        }
    }
}
