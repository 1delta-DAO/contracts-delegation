// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IUniswapV2PairAndERC20 {
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

struct TokenFees {
    uint256 buyFeeBps;
    uint256 sellFeeBps;
}

/// @notice Detects the buy and sell fee for a fee-on-transfer token
contract FeeOnTransferDetector {
    error SameToken();
    error PairLookupFailed();

    uint256 constant BPS = 10_000;
    // factory address
    address internal immutable factoryV2;
    // pair code hash
    bytes32 internal immutable codeHash;
    // solidly flag
    bool internal immutable isSolidly;

    constructor(address _factoryV2, bytes32 _codeHash, bool _isSolidly) {
        factoryV2 = _factoryV2;
        codeHash = _codeHash;
        isSolidly = _isSolidly;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB);
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(isSolidly ? abi.encodePacked(token0, token1, false) : abi.encodePacked(token0, token1)),
                            codeHash // init code hash
                        )
                    )
                )
            )
        );
    }

    /// @notice detects FoT fees for a single token
    function validate(address token, address baseToken, uint256 amountToBorrow) public returns (TokenFees memory fotResult) {
        return _validate(token, baseToken, amountToBorrow);
    }

    /// @notice detects FoT fees for a batch of tokens
    function batchValidate(
        address[] calldata tokens, //
        address baseToken,
        uint256 amountToBorrow
    )
        public
        returns (TokenFees[] memory fotResults)
    {
        fotResults = new TokenFees[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            fotResults[i] = _validate(tokens[i], baseToken, amountToBorrow);
        }
    }

    function _validate(address token, address baseToken, uint256 amountToBorrow) internal returns (TokenFees memory result) {
        if (token == baseToken) {
            revert SameToken();
        }

        address pairAddress = pairFor(factoryV2, token, baseToken);

        // If the token/baseToken pair exists, get token0.
        // Must do low level call as try/catch does not support case where contract does not exist.
        (, bytes memory returnData) = address(pairAddress).call(abi.encodeWithSelector(IUniswapV2PairAndERC20.token0.selector));

        if (returnData.length == 0) {
            revert PairLookupFailed();
        }

        address token0Address = abi.decode(returnData, (address));

        // Flash loan {amountToBorrow}
        (uint256 amount0Out, uint256 amount1Out) = token == token0Address ? (amountToBorrow, uint256(0)) : (uint256(0), amountToBorrow);

        uint256 balanceBeforeLoan = IUniswapV2PairAndERC20(token).balanceOf(address(this));

        IUniswapV2PairAndERC20 pair = IUniswapV2PairAndERC20(pairAddress);

        try pair.swap(amount0Out, amount1Out, address(this), abi.encode(balanceBeforeLoan, amountToBorrow)) {}
        catch (bytes memory reason) {
            result = parseRevertReason(reason);
        }
    }

    function parseRevertReason(bytes memory reason) private pure returns (TokenFees memory) {
        if (reason.length != 64) {
            assembly {
                revert(add(32, reason), mload(reason))
            }
        } else {
            return abi.decode(reason, (TokenFees));
        }
    }

    function uniswapV2Call(address, uint256 amount0, uint256, bytes calldata data) external {
        IUniswapV2PairAndERC20 pair = IUniswapV2PairAndERC20(msg.sender);
        (address token0, address token1) = (pair.token0(), pair.token1());

        IUniswapV2PairAndERC20 tokenBorrowed = IUniswapV2PairAndERC20(amount0 > 0 ? token0 : token1);

        (uint256 balanceBeforeLoan, uint256 amountRequestedToBorrow) = abi.decode(data, (uint256, uint256));
        uint256 amountBorrowed = tokenBorrowed.balanceOf(address(this)) - balanceBeforeLoan;

        uint256 buyFeeBps = (amountRequestedToBorrow - amountBorrowed) * BPS / amountRequestedToBorrow;
        balanceBeforeLoan = tokenBorrowed.balanceOf(address(pair));
        uint256 sellFeeBps;
        try tokenBorrowed.transfer(address(pair), amountBorrowed) {
            uint256 sellFee = amountBorrowed - (tokenBorrowed.balanceOf(address(pair)) - balanceBeforeLoan);
            sellFeeBps = sellFee * BPS / amountBorrowed;
        } catch (bytes memory) {
            sellFeeBps = buyFeeBps;
        }

        bytes memory fees = abi.encode(TokenFees({buyFeeBps: buyFeeBps, sellFeeBps: sellFeeBps}));

        // revert with the abi encoded fees
        assembly {
            revert(add(32, fees), mload(fees))
        }
    }
}
