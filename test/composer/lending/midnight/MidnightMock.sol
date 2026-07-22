// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// ── Morpho Midnight structs (field order fixes the ABI selectors the composer targets) ──

struct CollateralParams {
    address token;
    uint256 lltv;
    uint256 liquidationCursor;
    address oracle;
}

struct Market {
    uint256 chainId;
    address midnight;
    address loanToken;
    CollateralParams[] collateralParams;
    uint256 maturity;
    uint256 rcfThreshold;
    address enterGate;
    address liquidatorGate;
}

struct Offer {
    Market market;
    bool buy;
    address maker;
    uint256 start;
    uint256 expiry;
    uint256 tick;
    bytes32 group;
    address callback;
    bytes callbackData;
    address receiverIfMakerIsSeller;
    address ratifier;
    bool reduceOnly;
    uint128 maxUnits;
    uint128 maxAssets;
    uint256 continuousFeeCap;
}

interface IERC20Min {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

interface IMidnightFlashLoanReceiver {
    function onFlashLoan(
        address caller,
        address[] calldata tokens,
        uint256[] calldata assets,
        bytes calldata data
    )
        external
        returns (bytes32);
}

/**
 * @notice Faithful-enough Morpho Midnight stand-in for composer unit tests.
 * @dev Reproduces the exact function signatures (hence selectors) the composer builds, records the
 *      decoded arguments so tests can assert pinning/injection/relay, and performs the same token
 *      pulls/pushes as the real protocol so fund-flow can be checked. Economics (ticks, offers,
 *      ratifiers, maturity) are intentionally omitted - those are Morpho's concern, not the composer's.
 */
contract MidnightMock {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("morpho.midnight.callbackSuccess");

    // last-call captures
    string public lastFn;
    address public lastOnBehalf;
    address public lastReceiver;
    address public lastTaker;
    address public lastTakerCallback;
    address public lastCaller; // msg.sender of the last op (== composer)
    uint256 public lastUnits;
    uint256 public lastAssets;
    uint256 public lastCollateralIndex;
    address public lastLoanToken;
    address public lastCollateralToken;
    bool public lastBuy;

    // flash-loan captures
    bool public flashLoanCalled;
    address public lastFlashInitiator;
    address public lastFlashToken0;
    uint256 public lastFlashAmount0;
    uint256 public lastFlashTokenCount;

    function supplyCollateral(Market memory market, uint256 collateralIndex, uint256 assets, address onBehalf) external {
        lastFn = "supplyCollateral";
        lastCaller = msg.sender;
        lastCollateralIndex = collateralIndex;
        lastAssets = assets;
        lastOnBehalf = onBehalf;
        address token = market.collateralParams[collateralIndex].token;
        lastCollateralToken = token;
        IERC20Min(token).transferFrom(msg.sender, address(this), assets);
    }

    function withdrawCollateral(
        Market memory market,
        uint256 collateralIndex,
        uint256 assets,
        address onBehalf,
        address receiver
    )
        external
    {
        lastFn = "withdrawCollateral";
        lastCaller = msg.sender;
        lastCollateralIndex = collateralIndex;
        lastAssets = assets;
        lastOnBehalf = onBehalf;
        lastReceiver = receiver;
        address token = market.collateralParams[collateralIndex].token;
        lastCollateralToken = token;
        IERC20Min(token).transfer(receiver, assets);
    }

    // exact-debt read support: mirrors the real `debt(bytes32 id, address user) view returns (uint128)`
    mapping(bytes32 => mapping(address => uint128)) public debtBook;

    function setDebt(bytes32 id, address user, uint128 units) external {
        debtBook[id][user] = units;
    }

    function debt(bytes32 id, address user) external view returns (uint128) {
        return debtBook[id][user];
    }

    // max-withdraw read support:
    // - collateral(id,user,index): exact stored collateral (never accrues) — for withdrawCollateral-max
    // - updatePositionView(market,id,user): accrual-aware redeemable credit (return[0]) — for withdraw-max
    mapping(bytes32 => mapping(address => uint128)) public creditBook;
    mapping(bytes32 => mapping(address => mapping(uint256 => uint128))) public collateralBook;

    function setCredit(bytes32 id, address user, uint128 units) external {
        creditBook[id][user] = units;
    }

    function setCollateral(bytes32 id, address user, uint256 index, uint128 amount) external {
        collateralBook[id][user][index] = amount;
    }

    function collateral(bytes32 id, address user, uint256 index) external view returns (uint128) {
        return collateralBook[id][user][index];
    }

    function updatePositionView(Market memory, bytes32 id, address user) external view returns (uint128, uint128, uint128) {
        return (creditBook[id][user], 0, 0);
    }

    function repay(Market memory market, uint256 units, address onBehalf, address callback, bytes memory) external {
        lastFn = "repay";
        lastCaller = msg.sender;
        lastUnits = units;
        lastOnBehalf = onBehalf;
        lastTakerCallback = callback; // composer forces this to 0
        lastLoanToken = market.loanToken;
        // callback == 0 => payer is msg.sender (the composer)
        IERC20Min(market.loanToken).transferFrom(msg.sender, address(this), units);
    }

    function withdraw(Market memory market, uint256 units, address onBehalf, address receiver) external {
        lastFn = "withdraw";
        lastCaller = msg.sender;
        lastUnits = units;
        lastOnBehalf = onBehalf;
        lastReceiver = receiver;
        lastLoanToken = market.loanToken;
        IERC20Min(market.loanToken).transfer(receiver, units);
    }

    function take(
        Offer memory offer,
        bytes memory,
        uint256 units,
        address taker,
        address receiverIfTakerIsSeller,
        address takerCallback,
        bytes memory
    )
        external
        returns (uint256, uint256)
    {
        lastFn = "take";
        lastCaller = msg.sender;
        lastUnits = units;
        lastTaker = taker;
        lastReceiver = receiverIfTakerIsSeller;
        lastTakerCallback = takerCallback; // composer forces this to 0
        lastBuy = offer.buy;
        lastLoanToken = offer.market.loanToken;
        if (offer.buy) {
            // maker is the buyer/lender, taker is the seller/borrower: send borrow proceeds to receiver
            IERC20Min(offer.market.loanToken).transfer(receiverIfTakerIsSeller, units);
        } else {
            // taker is the buyer/lender: pull payment from the composer
            IERC20Min(offer.market.loanToken).transferFrom(msg.sender, address(this), units);
        }
        return (units, units);
    }

    function flashLoan(address[] memory tokens, uint256[] memory assets, address callback, bytes memory data) external {
        flashLoanCalled = true;
        lastFlashInitiator = callback;
        lastFlashTokenCount = tokens.length;
        if (tokens.length > 0) {
            lastFlashToken0 = tokens[0];
            lastFlashAmount0 = assets[0];
        }
        for (uint256 i; i < tokens.length; i++) {
            IERC20Min(tokens[i]).transfer(callback, assets[i]);
        }
        require(
            IMidnightFlashLoanReceiver(callback).onFlashLoan(msg.sender, tokens, assets, data) == CALLBACK_SUCCESS, "bad-callback"
        );
        for (uint256 i; i < tokens.length; i++) {
            IERC20Min(tokens[i]).transferFrom(callback, address(this), assets[i]);
        }
    }
}
