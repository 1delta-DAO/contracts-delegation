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

    function getUniswapV2Info(address factoryAddress, uint256 indexFrom) external view returns (UniswapV2Info[] memory) {
        IFactory factory = IFactory(factoryAddress);
        uint256 totalPools = factory.allPairsLength();
        
        require(indexFrom < totalPools, "Index out of range");
        
        UniswapV2Info[] memory poolsInfo = new UniswapV2Info[](totalPools - indexFrom);
        
        for (uint256 i = indexFrom; i < totalPools; i++) {
            address poolAddress = factory.allPairs(i);
            IPool pool = IPool(poolAddress);

            address token0Address = pool.token0();
            address token1Address = pool.token1();
            
            IERC20 token0 = IERC20(token0Address);
            IERC20 token1 = IERC20(token1Address);
            
            ERC20Info memory token0Info = ERC20Info({
                tokenAddress: token0Address,
                name: token0.name(),
                symbol: token0.symbol(),
                decimals: token0.decimals(),
                totalSupply: token0.totalSupply(),
                reserve: token0.balanceOf(poolAddress)
            });
            
            ERC20Info memory token1Info = ERC20Info({
                tokenAddress: token1Address,
                name: token1.name(),
                symbol: token1.symbol(),
                decimals: token1.decimals(),
                totalSupply: token1.totalSupply(),
                reserve: token1.balanceOf(poolAddress)
            });
            
            poolsInfo[i] = UniswapV2Info({
                index: i,
                pairAddress: poolAddress,
                token0Info: token0Info,
                token1Info: token1Info
            });
        }
        
        return poolsInfo;
    }
}