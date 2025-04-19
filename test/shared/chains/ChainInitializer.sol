// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../data/LenderRegistry.sol";

interface IChain {
    function getTokenAddress(string memory tokenSymbol) external view returns (address);

    function getLendingTokens(address token, string memory protocol) external view returns (LenderTokens memory);

    function getCometToBase(string memory protocol) external view returns (address);

    function getLendingController(string memory protocol) external view returns (address);

    function getChainId() external view returns (uint256);

    function getChainName() external view returns (string memory);

    function getRpcUrl() external view returns (string memory);

    function getCollateralBalance(address user, address underlying, string memory lender) external returns (uint256 balance);

    function getDebtBalance(address user, address underlying, string memory lender) external returns (uint256 balance);
}

interface ILendingTools {
    // balance (collateral and debt fpor aave)
    function balanceOf(address account) external view returns (uint256);

    // general (aave and compound V2)
    function approve(address spender, uint256 amount) external returns (bool);

    // credit delegation
    function approveDelegation(address delegatee, uint256 amount) external;

    // compound V2
    function balanceOfUnderlying(address owner) external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function enterMarkets(address[] calldata vTokens) external returns (uint256[] memory);

    function exitMarket(address vToken) external returns (uint256);

    // delegation
    function updateDelegate(address delegate, bool allowBorrows) external;

    // compound V3
    function collateralBalanceOf(address account, address asset) external view returns (uint128);

    function borrowBalanceOf(address account) external view returns (uint256);

    // delegation (all in one)
    function allow(address manager, bool isAllowed) external;
}

contract Chain is LenderRegistry, IChain {
    string private chainName;

    constructor(string memory _chainName) {
        chainName = _chainName;
    }

    function getChainId() public view override returns (uint256) {
        return _getChainId(chainName);
    }

    function getChainName() public view override returns (string memory) {
        return chainName;
    }

    function getRpcUrl() public view override returns (string memory) {
        return _getChainRpc(chainName);
    }

    function getTokenAddress(string memory tokenSymbol) public view override returns (address) {
        address tokenAddress = tokens[chainName][tokenSymbol];
        require(tokenAddress != address(0), "Token not available for this chain");
        return tokenAddress;
    }

    function getLendingTokens(address token, string memory lender) public view override returns (LenderTokens memory) {
        return lendingTokens[chainName][lender][token];
    }

    function getCometToBase(string memory lender) public view override returns (address) {
        return cometToBase[chainName][lender];
    }

    function getLendingController(string memory lender) public view override returns (address) {
        return lendingControllers[chainName][lender];
    }

    // for compound v2, this might accure interest
    function getCollateralBalance(address user, address underlying, string memory lender) public override returns (uint256 balance) {
        if (Lenders.isAave(lender)) {
            return ILendingTools(lendingTokens[getChainName()][lender][underlying].collateral).balanceOf(user);
        } else if (Lenders.isCompoundV2(lender)) {
            return ILendingTools(lendingTokens[getChainName()][lender][underlying].collateral).balanceOfUnderlying(user);
        } else if (Lenders.isCompoundV3(lender)) {
            address base = cometToBase[getChainName()][lender];
            if (underlying == base) {
                return ILendingTools(lendingControllers[getChainName()][lender]).balanceOf(user);
            }
            return ILendingTools(lendingControllers[getChainName()][lender]).collateralBalanceOf(underlying, user);
        }
    }

    // for compound v2, this might accure interest
    function getDebtBalance(address user, address underlying, string memory lender) public override returns (uint256 balance) {
        if (Lenders.isAave(lender)) {
            return ILendingTools(lendingTokens[getChainName()][lender][underlying].debt).balanceOf(user);
        } else if (Lenders.isCompoundV2(lender)) {
            return ILendingTools(lendingTokens[getChainName()][lender][underlying].collateral).borrowBalanceCurrent(user);
        } else if (Lenders.isCompoundV3(lender)) {
            address base = cometToBase[getChainName()][lender];
            if (underlying == base) {
                revert("cannot borrow base");
            }
            return ILendingTools(lendingControllers[getChainName()][lender]).borrowBalanceOf(user);
        }
    }
}
