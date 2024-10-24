// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFactory {
    function allPairsLength() external view returns (uint256);

    function allPairs(uint256) external view returns (address);
}

interface IPool {
    function token0() external view returns (address);

    function token1() external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);
}

contract PoolReader {
    struct ERC20Info {
        address tokenAddress;
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        uint256 reserve;
    }

    struct UniswapV2Info {
        uint256 index;
        address pairAddress;
        ERC20Info token0Info;
        ERC20Info token1Info;
    }

    function getUniswapV2Info(address factoryAddress, uint256 indexFrom, uint256 indexTo) external view returns (UniswapV2Info[] memory) {
        IFactory factory = IFactory(factoryAddress);
        uint256 totalPools = factory.allPairsLength();

        if (indexTo > totalPools) {
            indexTo = totalPools;
        }

        require(indexFrom < indexTo, "Index out of range");

        UniswapV2Info[] memory tempPoolsInfo = new UniswapV2Info[](indexTo - indexFrom);

        uint poolIndex = 0;
        for (uint256 i = indexFrom; i < indexTo; i++) {
            address poolAddress = factory.allPairs(i);
            IPool pool = IPool(poolAddress);

            address token0Address;
            address token1Address;

            try pool.token0() returns (address addr) {
                token0Address = addr;
            } catch {
                continue;
            }

            try pool.token1() returns (address addr) {
                token1Address = addr;
            } catch {
                continue;
            }

            ERC20Info memory token0Info = getTokenInfo(token0Address, poolAddress);
            ERC20Info memory token1Info = getTokenInfo(token1Address, poolAddress);

            if (bytes(token0Info.name).length == 0 || bytes(token1Info.name).length == 0) {
                continue;
            }

            tempPoolsInfo[poolIndex] = UniswapV2Info({index: i, pairAddress: poolAddress, token0Info: token0Info, token1Info: token1Info});
            poolIndex++;
        }

        UniswapV2Info[] memory poolsInfo = new UniswapV2Info[](poolIndex);
        for (uint256 i = 0; i < poolIndex; i++) {
            poolsInfo[i] = tempPoolsInfo[i];
        }

        return poolsInfo;
    }

    function getTokenInfo(address tokenAddress, address poolAddress) internal view returns (ERC20Info memory) {
        IERC20 token = IERC20(tokenAddress);

        ERC20Info memory info;
        info.tokenAddress = tokenAddress;

        try token.name() returns (string memory name) {
            info.name = name;
        } catch {
            return ERC20Info(address(0), "", "", 0, 0, 0);
        }

        try token.symbol() returns (string memory symbol) {
            info.symbol = symbol;
        } catch {
            return ERC20Info(address(0), "", "", 0, 0, 0);
        }

        try token.decimals() returns (uint8 decimals) {
            info.decimals = decimals;
        } catch {
            return ERC20Info(address(0), "", "", 0, 0, 0);
        }

        try token.totalSupply() returns (uint256 totalSupply) {
            info.totalSupply = totalSupply;
        } catch {
            return ERC20Info(address(0), "", "", 0, 0, 0);
        }

        try token.balanceOf(poolAddress) returns (uint256 reserve) {
            info.reserve = reserve;
        } catch {
            return ERC20Info(address(0), "", "", 0, 0, 0);
        }

        return info;
    }
}
