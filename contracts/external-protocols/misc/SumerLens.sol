// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICToken {
    function comptroller() external view returns (address);

    function reserveFactorMantissa() external view returns (uint256);

    function borrowIndex() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function isCToken() external view returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function underlying() external view returns (address);

    function exchangeRateCurrent() external returns (uint256);

    function isCEther() external view returns (bool);

    function supplyRatePerBlock() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function totalReserves() external view returns (uint256);

    function getCash() external view returns (uint256);

    function decimals() external view returns (uint8);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function getCurrentVotes(address account) external view returns (uint96);

    function delegates(address) external view returns (address);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);

    function executeRedemption(
        address redeemer,
        address provider,
        uint256 repayAmount,
        address cTokenCollateral,
        uint256 seizeAmount,
        uint256 redemptionRateMantissa
    )
        external;

    function discountRateMantissa() external view returns (uint256);

    function accrueInterest() external;

    function liquidateCalculateSeizeTokens(
        address cTokenCollateral,
        uint256 actualRepayAmount
    )
        external
        view
        returns (uint256, uint256);

    function protocolSeizeShareMantissa() external view returns (uint256);
}

interface IPriceOracle {
    /**
     * @notice Get the underlying price of a cToken asset
     * @param cToken The cToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable.
     */
    function getUnderlyingPrice(address cToken) external view returns (uint256);

    /**
     * @notice Get the underlying price of cToken asset (normalized)
     * = getUnderlyingPrice * (10 ** (18 - cToken.decimals))
     */
    function getUnderlyingPriceNormalized(address cToken_) external view returns (uint256);
}

abstract contract IGovernorAlpha {
    struct Proposal {
        // Unique id for looking up a proposal
        uint256 id;
        // Creator of the proposal
        address proposer;
        // The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        // the ordered list of target addresses for calls to be made
        address[] targets;
        // The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint256[] values;
        // The ordered list of function signatures to be called
        string[] signatures;
        // The ordered list of calldata to be passed to each call
        bytes[] calldatas;
        // The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        // The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;
        // Current number of votes in favor of this proposal
        uint256 forVotes;
        // Current number of votes in opposition to this proposal
        uint256 againstVotes;
        // Flag marking whether the proposal has been canceled
        bool canceled;
        // Flag marking whether the proposal has been executed
        bool executed;
        // Receipts of ballots for the entire set of voters
        mapping(address => Receipt) receipts;
    }
    // Ballot receipt record for a voter
    // Whether or not a vote has been cast
    // Whether or not the voter supports the proposal
    // The number of votes the voter had, which were cast

    struct Receipt {
        bool hasVoted;
        bool support;
        uint96 votes;
    }

    function getReceipt(uint256 proposalId, address voter) external view virtual returns (bool, bool, uint96);

    mapping(uint256 => Proposal) public proposals;

    function getActions(uint256 proposalId)
        public
        view
        virtual
        returns (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas);
}

enum Version {
    V0,
    V1,
    V2, // packed asset group
    V3, // added interMintRate into asset group
    V4 // use interMintSwitch instead of interMintRate

}

struct GroupVar {
    uint8 groupId;
    uint256 cDepositVal;
    uint256 cBorrowVal;
    uint256 suDepositVal;
    uint256 suBorrowVal;
    uint256 intraCRate;
    uint256 intraMintRate;
    uint256 intraSuRate;
    uint256 interCRate;
    uint256 interSuRate;
}

/// @notice AssetGroup, contains information of groupName and rateMantissas
struct AssetGroupDeprecated {
    uint8 groupId;
    string groupName;
    uint256 intraCRateMantissa;
    uint256 intraMintRateMantissa;
    uint256 intraSuRateMantissa;
    uint256 interCRateMantissa;
    uint256 interSuRateMantissa;
    bool exist;
}

/// @notice NewAssetGroup, contains information of groupName and rateMantissas
struct CompactAssetGroup {
    uint8 groupId;
    uint16 intraCRatePercent;
    uint16 intraMintRatePercent;
    uint16 intraSuRatePercent;
    uint16 interCRatePercent;
    uint16 interSuRatePercent;
}

struct GlobalConfig {
    uint16 closeFactorPercent; // percent decimals(4)
    uint32 minCloseValue; // usd value decimals(0)
    uint32 minSuBorrowValue; // usd value decimals(0)
    uint32 minWaitBeforeLiquidatable; // seconds decimals(0)
    uint8 largestGroupId;
}

struct MarketConfig {
    bool mintPaused;
    bool borrowPaused;
    bool transferPaused;
    bool seizePaused;
    uint120 borrowCap; //
    uint120 supplyCap;
}

struct LiquidationIncentive {
    uint16 heteroPercent;
    uint16 homoPercent;
    uint16 sutokenPercent;
}

interface IComptroller {
    /**
     * Assets You Are In **
     */
    function isComptroller() external view returns (bool);

    function markets(address) external view returns (bool, uint8, bool);

    function getAllMarkets() external view returns (address[] memory);

    function oracle() external view returns (address);

    function redemptionManager() external view returns (address);

    function enterMarkets(address[] calldata cTokens) external;

    function exitMarket(address cToken) external;

    // function getAssetsIn(address) external view returns (ICToken[] memory);
    function claimSumer(address) external;

    function compAccrued(address) external view returns (uint256);

    function getAssetsIn(address account) external view returns (address[] memory);

    function timelock() external view returns (address);

    function getUnderlyingPriceNormalized(address cToken) external view returns (uint256);
    /**
     * Policy Hooks **
     */
    function mintAllowed(address cToken, address minter, uint256 mintAmount, uint256 exchangeRate) external;

    function redeemAllowed(address cToken, address redeemer, uint256 redeemTokens, uint256 exchangeRate) external;
    function redeemVerify(address cToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens) external;

    function borrowAllowed(address cToken, address borrower, uint256 borrowAmount) external;
    function borrowVerify(address borrower, uint256 borrowAmount) external;

    function repayBorrowAllowed(address cToken, address payer, address borrower, uint256 repayAmount) external;
    function repayBorrowVerify(
        address cToken,
        address payer,
        address borrower,
        uint256 actualRepayAmount,
        uint256 borrowIndex
    )
        external;

    function seizeAllowed(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    )
        external;
    function seizeVerify(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    )
        external;

    function transferAllowed(address cToken, address src, address dst, uint256 transferTokens) external;

    /**
     * Liquidity/Liquidation Calculations **
     */
    function liquidationIncentive() external view returns (LiquidationIncentive memory);

    function isListed(address asset) external view returns (bool);

    function getHypotheticalAccountLiquidity(
        address account,
        address cTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    )
        external
        view
        returns (uint256, uint256);

    // function _getMarketBorrowCap(address cToken) external view returns (uint256);

    /// @notice Emitted when an action is paused on a market
    event ActionPaused(address cToken, string action, bool pauseState);

    /// @notice Emitted when borrow cap for a cToken is changed
    event NewBorrowCap(address indexed cToken, uint256 newBorrowCap);

    /// @notice Emitted when borrow cap guardian is changed
    event NewBorrowCapGuardian(address oldBorrowCapGuardian, address newBorrowCapGuardian);

    /// @notice Emitted when pause guardian is changed
    event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);

    event RemoveAssetGroup(uint8 indexed groupId, uint8 equalAssetsGroupNum);

    function assetGroup(uint8 groupId) external view returns (CompactAssetGroup memory);

    function marketConfig(address cToken) external view returns (MarketConfig memory);

    function liquidateBorrowAllowed(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    )
        external
        view;
    function liquidateBorrowVerify(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount,
        uint256 seizeTokens
    )
        external;

    function globalConfig() external view returns (GlobalConfig memory);

    function interMintAllowed() external view returns (bool);
}

interface IGovernorBravo {
    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }

    struct Proposal {
        uint256 id;
        address proposer;
        uint256 eta;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
    }

    function getActions(uint256 proposalId)
        external
        view
        returns (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas);

    function proposals(uint256 proposalId) external view returns (Proposal memory);

    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory);
}

/**
 * @title Exponential module for storing fixed-precision decimals
 * @author Compound
 * @notice Exp is a struct which stores decimals with a fixed precision of 18 decimal places.
 *         Thus, if we wanted to store the 5.1, mantissa would store 5.1e18. That is:
 *         `Exp({mantissa: 5100000000000000000})`.
 */
contract ExponentialNoErrorNew {
    uint256 constant expScale = 1e18;
    uint256 constant doubleScale = 1e36;

    struct Exp {
        uint256 mantissa;
    }

    struct Double {
        uint256 mantissa;
    }

    /**
     * @dev Truncates the given exp to a whole number value.
     *      For example, truncate(Exp{mantissa: 15 * expScale}) = 15
     */
    function truncate(Exp memory exp) internal pure returns (uint256) {
        // Note: We are not using careful math here as we're performing a division that cannot fail
        return exp.mantissa / expScale;
    }

    /**
     * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
     */
    function mul_ScalarTruncate(Exp memory a, uint256 scalar) internal pure returns (uint256) {
        Exp memory product = mul_(a, scalar);
        return truncate(product);
    }

    /**
     * @dev Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.
     */
    function mul_ScalarTruncateAddUInt(Exp memory a, uint256 scalar, uint256 addend) internal pure returns (uint256) {
        Exp memory product = mul_(a, scalar);
        return add_(truncate(product), addend);
    }

    /**
     * @dev Checks if first Exp is less than second Exp.
     */
    function lessThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa < right.mantissa;
    }

    /**
     * @dev Checks if left Exp <= right Exp.
     */
    function lessThanOrEqualExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa <= right.mantissa;
    }

    /**
     * @dev Checks if left Exp > right Exp.
     */
    function greaterThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa > right.mantissa;
    }

    /**
     * @dev returns true if Exp is exactly zero
     */
    function isZeroExp(Exp memory value) internal pure returns (bool) {
        return value.mantissa == 0;
    }

    function safe224(uint256 n, string memory errorMessage) internal pure returns (uint224) {
        require(n < 2 ** 224, errorMessage);
        return uint224(n);
    }

    function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2 ** 32, errorMessage);
        return uint32(n);
    }

    function add_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: add_(a.mantissa, b.mantissa)});
    }

    function add_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: add_(a.mantissa, b.mantissa)});
    }

    function add_(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: sub_(a.mantissa, b.mantissa)});
    }

    function sub_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: sub_(a.mantissa, b.mantissa)});
    }

    function sub_(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b.mantissa) / expScale});
    }

    function mul_(Exp memory a, uint256 b) internal pure returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b)});
    }

    function mul_(uint256 a, Exp memory b) internal pure returns (uint256) {
        return mul_(a, b.mantissa) / expScale;
    }

    function mul_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: mul_(a.mantissa, b.mantissa) / doubleScale});
    }

    function mul_(Double memory a, uint256 b) internal pure returns (Double memory) {
        return Double({mantissa: mul_(a.mantissa, b)});
    }

    function mul_(uint256 a, Double memory b) internal pure returns (uint256) {
        return mul_(a, b.mantissa) / doubleScale;
    }

    function mul_(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: div_(mul_(a.mantissa, expScale), b.mantissa)});
    }

    function div_(Exp memory a, uint256 b) internal pure returns (Exp memory) {
        return Exp({mantissa: div_(a.mantissa, b)});
    }

    function div_(uint256 a, Exp memory b) internal pure returns (uint256) {
        return div_(mul_(a, expScale), b.mantissa);
    }

    function div_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: div_(mul_(a.mantissa, doubleScale), b.mantissa)});
    }

    function div_(Double memory a, uint256 b) internal pure returns (Double memory) {
        return Double({mantissa: div_(a.mantissa, b)});
    }

    function div_(uint256 a, Double memory b) internal pure returns (uint256) {
        return div_(mul_(a, doubleScale), b.mantissa);
    }

    function div_(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function fraction(uint256 a, uint256 b) internal pure returns (Double memory) {
        return Double({mantissa: div_(mul_(a, doubleScale), b)});
    }
}

contract SumerErrors {
    error PriceError();

    error TotalBorrowsNotZero();
    error TotalSupplyNotZero();
    error RedemptionSignerNotInitialized();
    error NotEnoughForSeize();
    error NoRedemptionProvider();
    error OnlyPausedMarketCanBeUnlisted();
    error MarketNotListed();
    error InsufficientShortfall();
    error TooMuchRepay();
    error InvalidCToken();
    error MarketNotEmpty();
    error InvalidMinSuBorrowValue();
    error BorrowValueMustBeLargerThanThreshold(uint256 usdThreshold);
    error OverThreshold();
    error MarketAlreadyListed();
    error MarketAlreadyUnlisted();
    error InvalidAddress();
    error InvalidGroupId();
    error InvalidCloseFactor();
    error InvalidSuToken();
    error InvalidSignatureLength();
    error ExpiredSignature();
    error SenderMustBeCToken();
    error MintPaused();
    error BorrowPaused();
    error MarketPaused();
    error TransferPaused();
    error SeizePaused();
    error InsufficientCollateral();
    error EitherAssetOrDebtMustBeZeroInGroup(
        uint8 groupId, uint256 cDepositVal, uint256 suDepositVal, uint256 cBorrowVal, uint256 suBorrowVal
    );
    error EitherAssetOrDebtMustBeZero();

    error OnlyAdminOrPauser();

    // general errors
    error OnlyAdmin();
    error OnlyPendingAdmin();
    error OnlyRedemptionManager();
    error OnlyListedCToken();
    error OnlyCToken();
    error UnderlyingBalanceError();
    error MarketCanOnlyInitializeOnce();
    error CantSweepUnderlying();
    error TokenTransferInFailed();
    error TokenTransferOutFailed();
    error TransferNotAllowed();
    error TokenInOrAmountInMustBeZero();
    error AddReservesOverflow();
    error RedeemTransferOutNotPossible();
    error BorrowCashNotAvailable();
    error ReduceReservesCashNotAvailable();
    error InvalidRedeem();
    error CantEnterPausedMarket();
    error InvalidDiscountRate();
    error InvalidExchangeRate();
    error InvalidReduceAmount();
    error InvalidReserveFactor();
    error InvalidComptroller();
    error InvalidInterestRateModel();
    error InvalidAmount();
    error InvalidInput();
    error BorrowAndDepositBackFailed();
    error InvalidSignatureForRedeemFaceValue();

    error BorrowCapReached();
    error SupplyCapReached();
    error ComptrollerMismatch();

    error MintMarketNotFresh();
    error BorrowMarketNotFresh();
    error RepayBorrowMarketNotFresh();
    error RedeemMarketNotFresh();
    error LiquidateMarketNotFresh();
    error LiquidateCollateralMarketNotFresh();
    error ReduceReservesMarketNotFresh();
    error SetInterestRateModelMarketNotFresh();
    error AddReservesMarketNotFresh();
    error SetReservesFactorMarketNotFresh();
    error CantExitMarketWithNonZeroBorrowBalance();
    error MintTokensCantBeZero();
    error NotEnoughUnderlyingForMint();
    error NotEnoughUnderlyingAfterRedeem();
    error NotEnoughRedeemTokens();
    error NotEnoughRedeemAmount();

    error InvalidTimestamp();

    // error
    error NotCToken();
    error NotSuToken();

    // error in liquidateBorrow
    error LiquidateBorrow_RepayAmountIsZero();
    error LiquidateBorrow_RepayAmountIsMax();
    error LiquidateBorrow_LiquidatorIsBorrower();
    error LiquidateBorrow_SeizeTooMuch();

    // error in seize
    error Seize_LiquidatorIsBorrower();

    // error in protected mint
    error ProtectedMint_OnlyAllowAssetsInTheSameGroup();

    error RedemptionSeizeTooMuch();

    error MinDelayNotReached();

    error NotLiquidatableYet();

    error InvalidBlockNumber();
    error ZeroAddressNotAllowed();
    error InterMintNotAllowed();

    error RepayTokenNotListed();
    error SeizeTokenNotListed();
    error Reentered();
}

contract SumerLens is ExponentialNoErrorNew, SumerErrors {
    uint256 public constant percentScale = 1e14;

    struct CTokenMetadata {
        address cToken;
        uint256 exchangeRateCurrent;
        uint256 supplyRatePerBlock;
        uint256 borrowRatePerBlock;
        uint256 reserveFactorMantissa;
        uint256 totalBorrows;
        uint256 totalReserves;
        uint256 totalSupply;
        uint256 totalCash;
        bool isListed;
        // uint256 collateralFactorMantissa;
        address underlyingAssetAddress;
        uint256 cTokenDecimals;
        uint256 underlyingDecimals;
        bool isCToken;
        bool isCEther;
        uint256 borrowCap;
        uint256 depositCap;
        uint256 heteroLiquidationIncentive;
        uint256 homoLiquidationIncentive;
        uint256 sutokenLiquidationIncentive;
        uint8 groupId;
        uint256 intraRate;
        uint256 mintRate;
        uint256 interRate;
        uint256 discountRate;
        bool interMintAllowed;
    }

    struct GroupInfo {
        uint256 intraRate;
        uint256 mintRate;
        uint256 interRate;
    }

    function cTokenMetadata(ICToken cToken) public returns (CTokenMetadata memory) {
        IComptroller comptroller = IComptroller(address(cToken.comptroller()));

        // get underlying info
        address underlyingAssetAddress;
        uint256 underlyingDecimals;
        if (cToken.isCEther()) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            underlyingAssetAddress = cToken.underlying();
            underlyingDecimals = ICToken(cToken.underlying()).decimals();
        }

        // get group info
        (bool isListed, uint8 assetGroupId,) = comptroller.markets(address(cToken));
        CompactAssetGroup memory group = comptroller.assetGroup(assetGroupId);
        GroupInfo memory gi;
        if (cToken.isCToken()) {
            gi.intraRate = uint256(group.intraCRatePercent) * percentScale;
            gi.interRate = uint256(group.interCRatePercent) * percentScale;
            gi.mintRate = uint256(group.intraMintRatePercent) * percentScale;
        } else {
            gi.intraRate = uint256(group.intraSuRatePercent) * percentScale;
            gi.interRate = uint256(group.interSuRatePercent) * percentScale;
            gi.mintRate = uint256(group.intraSuRatePercent) * percentScale;
        }
        LiquidationIncentive memory liquidationIncentive = comptroller.liquidationIncentive();
        return CTokenMetadata({
            cToken: address(cToken),
            exchangeRateCurrent: cToken.exchangeRateCurrent(),
            supplyRatePerBlock: cToken.supplyRatePerBlock(),
            borrowRatePerBlock: cToken.borrowRatePerBlock(),
            reserveFactorMantissa: cToken.reserveFactorMantissa(),
            totalBorrows: cToken.totalBorrows(),
            totalReserves: cToken.totalReserves(),
            totalSupply: cToken.totalSupply(),
            totalCash: cToken.getCash(),
            isListed: isListed,
            underlyingAssetAddress: underlyingAssetAddress,
            cTokenDecimals: cToken.decimals(),
            underlyingDecimals: underlyingDecimals,
            isCToken: cToken.isCToken(),
            isCEther: cToken.isCEther(),
            borrowCap: comptroller.marketConfig(address(cToken)).borrowCap,
            depositCap: comptroller.marketConfig(address(cToken)).supplyCap,
            heteroLiquidationIncentive: uint256(liquidationIncentive.heteroPercent) * percentScale,
            homoLiquidationIncentive: uint256(liquidationIncentive.homoPercent) * percentScale,
            sutokenLiquidationIncentive: uint256(liquidationIncentive.sutokenPercent) * percentScale,
            groupId: assetGroupId,
            intraRate: gi.intraRate,
            interRate: gi.interRate,
            mintRate: gi.mintRate,
            discountRate: cToken.discountRateMantissa(),
            interMintAllowed: comptroller.interMintAllowed()
        });
    }

    function cTokenMetadataAll(ICToken[] calldata cTokens) external returns (CTokenMetadata[] memory) {
        uint256 cTokenCount = cTokens.length;
        CTokenMetadata[] memory res = new CTokenMetadata[](cTokenCount);
        for (uint256 i = 0; i < cTokenCount; i++) {
            res[i] = cTokenMetadata(cTokens[i]);
        }
        return res;
    }

    struct CTokenBalances {
        address cToken;
        bool isCToken;
        bool isCEther;
        uint256 balanceOf;
        uint256 borrowBalanceCurrent;
        uint256 balanceOfUnderlying;
        uint256 tokenBalance;
        uint256 tokenAllowance;
    }

    function cTokenBalances(ICToken cToken, address payable account) public returns (CTokenBalances memory) {
        uint256 balanceOf = cToken.balanceOf(account);
        uint256 borrowBalanceCurrent = cToken.borrowBalanceCurrent(account);
        uint256 balanceOfUnderlying = cToken.balanceOfUnderlying(account);
        uint256 tokenBalance;
        uint256 tokenAllowance;

        if (cToken.isCEther()) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            ICToken underlying = ICToken(cToken.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(cToken));
        }

        return CTokenBalances({
            cToken: address(cToken),
            isCToken: cToken.isCToken(),
            isCEther: cToken.isCEther(),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }

    function cTokenBalancesAll(ICToken[] calldata cTokens, address payable account) external returns (CTokenBalances[] memory) {
        uint256 cTokenCount = cTokens.length;
        CTokenBalances[] memory res = new CTokenBalances[](cTokenCount);
        for (uint256 i = 0; i < cTokenCount; i++) {
            res[i] = cTokenBalances(cTokens[i], account);
        }
        return res;
    }

    struct CTokenUnderlyingPrice {
        address cToken;
        uint256 underlyingPrice;
    }

    function cTokenUnderlyingPrice(ICToken cToken) public view returns (CTokenUnderlyingPrice memory) {
        IComptroller comptroller = IComptroller(address(cToken.comptroller()));
        IPriceOracle priceOracle = IPriceOracle(comptroller.oracle());

        return CTokenUnderlyingPrice({cToken: address(cToken), underlyingPrice: priceOracle.getUnderlyingPrice(address(cToken))});
    }

    function cTokenUnderlyingPriceAll(ICToken[] calldata cTokens) external view returns (CTokenUnderlyingPrice[] memory) {
        uint256 cTokenCount = cTokens.length;
        CTokenUnderlyingPrice[] memory res = new CTokenUnderlyingPrice[](cTokenCount);
        for (uint256 i = 0; i < cTokenCount; i++) {
            res[i] = cTokenUnderlyingPrice(cTokens[i]);
        }
        return res;
    }

    struct AccountLimits {
        address[] markets;
        uint256 liquidity;
        uint256 shortfall;
    }

    function getAccountLimits(IComptroller comptroller, address account) external view returns (AccountLimits memory) {
        (uint256 liquidity, uint256 shortfall) = comptroller.getHypotheticalAccountLiquidity(account, address(0), 0, 0);

        return AccountLimits({markets: comptroller.getAssetsIn(account), liquidity: liquidity, shortfall: shortfall});
    }

    struct GovReceipt {
        uint256 proposalId;
        bool hasVoted;
        bool support;
        uint96 votes;
    }

    function getGovReceipts(
        IGovernorAlpha governor,
        address voter,
        uint256[] memory proposalIds
    )
        public
        view
        returns (GovReceipt[] memory)
    {
        uint256 proposalCount = proposalIds.length;
        GovReceipt[] memory res = new GovReceipt[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            IGovernorAlpha.Receipt memory receipt;

            (receipt.hasVoted, receipt.support, receipt.votes) = governor.getReceipt(proposalIds[i], voter);
            res[i] = GovReceipt({
                proposalId: proposalIds[i],
                hasVoted: receipt.hasVoted,
                support: receipt.support,
                votes: receipt.votes
            });
        }
        return res;
    }

    struct GovBravoReceipt {
        uint256 proposalId;
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }

    function getGovBravoReceipts(
        IGovernorBravo governor,
        address voter,
        uint256[] memory proposalIds
    )
        public
        view
        returns (GovBravoReceipt[] memory)
    {
        uint256 proposalCount = proposalIds.length;
        GovBravoReceipt[] memory res = new GovBravoReceipt[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            IGovernorBravo.Receipt memory receipt = governor.getReceipt(proposalIds[i], voter);
            res[i] = GovBravoReceipt({
                proposalId: proposalIds[i],
                hasVoted: receipt.hasVoted,
                support: receipt.support,
                votes: receipt.votes
            });
        }
        return res;
    }

    struct GovProposal {
        uint256 proposalId;
        address proposer;
        uint256 eta;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool canceled;
        bool executed;
    }

    function setProposal(GovProposal memory res, IGovernorAlpha governor, uint256 proposalId) internal view {
        (
            ,
            address proposer,
            uint256 eta,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes,
            bool canceled,
            bool executed
        ) = governor.proposals(proposalId);
        res.proposalId = proposalId;
        res.proposer = proposer;
        res.eta = eta;
        res.startBlock = startBlock;
        res.endBlock = endBlock;
        res.forVotes = forVotes;
        res.againstVotes = againstVotes;
        res.canceled = canceled;
        res.executed = executed;
    }

    function getGovProposals(
        IGovernorAlpha governor,
        uint256[] calldata proposalIds
    )
        external
        view
        returns (GovProposal[] memory)
    {
        GovProposal[] memory res = new GovProposal[](proposalIds.length);
        for (uint256 i = 0; i < proposalIds.length; i++) {
            (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas) =
                governor.getActions(proposalIds[i]);
            res[i] = GovProposal({
                proposalId: 0,
                proposer: address(0),
                eta: 0,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                startBlock: 0,
                endBlock: 0,
                forVotes: 0,
                againstVotes: 0,
                canceled: false,
                executed: false
            });
            setProposal(res[i], governor, proposalIds[i]);
        }
        return res;
    }

    struct GovBravoProposal {
        uint256 proposalId;
        address proposer;
        uint256 eta;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
    }

    function setBravoProposal(GovBravoProposal memory res, IGovernorBravo governor, uint256 proposalId) internal view {
        IGovernorBravo.Proposal memory p = governor.proposals(proposalId);

        res.proposalId = proposalId;
        res.proposer = p.proposer;
        res.eta = p.eta;
        res.startBlock = p.startBlock;
        res.endBlock = p.endBlock;
        res.forVotes = p.forVotes;
        res.againstVotes = p.againstVotes;
        res.abstainVotes = p.abstainVotes;
        res.canceled = p.canceled;
        res.executed = p.executed;
    }

    function getGovBravoProposals(
        IGovernorBravo governor,
        uint256[] calldata proposalIds
    )
        external
        view
        returns (GovBravoProposal[] memory)
    {
        GovBravoProposal[] memory res = new GovBravoProposal[](proposalIds.length);
        for (uint256 i = 0; i < proposalIds.length; i++) {
            (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas) =
                governor.getActions(proposalIds[i]);
            res[i] = GovBravoProposal({
                proposalId: 0,
                proposer: address(0),
                eta: 0,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                startBlock: 0,
                endBlock: 0,
                forVotes: 0,
                againstVotes: 0,
                abstainVotes: 0,
                canceled: false,
                executed: false
            });
            setBravoProposal(res[i], governor, proposalIds[i]);
        }
        return res;
    }

    struct CompBalanceMetadata {
        uint256 balance;
        uint256 votes;
        address delegate;
    }

    function getCompBalanceMetadata(ICToken comp, address account) external view returns (CompBalanceMetadata memory) {
        return CompBalanceMetadata({
            balance: comp.balanceOf(account),
            votes: uint256(comp.getCurrentVotes(account)),
            delegate: comp.delegates(account)
        });
    }

    struct CompBalanceMetadataExt {
        uint256 balance;
        uint256 votes;
        address delegate;
        uint256 allocated;
    }

    function getCompBalanceMetadataExt(
        ICToken comp,
        IComptroller comptroller,
        address account
    )
        external
        returns (CompBalanceMetadataExt memory)
    {
        uint256 balance = comp.balanceOf(account);
        comptroller.claimSumer(account);
        uint256 newBalance = comp.balanceOf(account);
        uint256 accrued = comptroller.compAccrued(account);
        uint256 total = add(accrued, newBalance, "sum comp total");
        uint256 allocated = sub(total, balance, "sub allocated");

        return CompBalanceMetadataExt({
            balance: balance,
            votes: uint256(comp.getCurrentVotes(account)),
            delegate: comp.delegates(account),
            allocated: allocated
        });
    }

    struct CompVotes {
        uint256 blockNumber;
        uint256 votes;
    }

    function getCompVotes(
        ICToken comp,
        address account,
        uint32[] calldata blockNumbers
    )
        external
        view
        returns (CompVotes[] memory)
    {
        CompVotes[] memory res = new CompVotes[](blockNumbers.length);
        for (uint256 i = 0; i < blockNumbers.length; i++) {
            res[i] =
                CompVotes({blockNumber: uint256(blockNumbers[i]), votes: uint256(comp.getPriorVotes(account, blockNumbers[i]))});
        }
        return res;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function add(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function getCollateralRate(
        IComptroller comptroller,
        address collateralToken,
        address liabilityToken
    )
        public
        view
        returns (uint256)
    {
        (bool isListedCollateral, uint8 collateralGroupId,) = comptroller.markets(collateralToken);
        if (!isListedCollateral) {
            revert MarketNotListed();
        }
        (bool isListedLiability, uint8 liabilityGroupId,) = comptroller.markets(liabilityToken);
        if (!isListedLiability) {
            revert MarketNotListed();
        }

        bool collateralIsCToken = ICToken(collateralToken).isCToken();
        bool liabilityIsCToken = ICToken(liabilityToken).isCToken();

        if (collateralIsCToken) {
            // collateral is cToken
            if (collateralGroupId == liabilityGroupId) {
                // collaterl/liability is in the same group
                if (liabilityIsCToken) {
                    return uint256(comptroller.assetGroup(collateralGroupId).intraCRatePercent) * percentScale;
                } else {
                    return uint256(comptroller.assetGroup(collateralGroupId).intraMintRatePercent) * percentScale;
                }
            } else {
                // collateral/liability is not in the same group
                return uint256(comptroller.assetGroup(collateralGroupId).interCRatePercent) * percentScale;
            }
        } else {
            // collateral is suToken
            if (collateralGroupId == liabilityGroupId) {
                // collaterl/liability is in the same group
                return uint256(comptroller.assetGroup(collateralGroupId).intraSuRatePercent) * percentScale;
            } else {
                // collateral/liability is not in the same group
                return uint256(comptroller.assetGroup(collateralGroupId).interSuRatePercent) * percentScale;
            }
        }
    }

    function calcBorrowAmountForProtectedMint(
        address account,
        address cTokenCollateral,
        address suToken,
        uint256 suBorrowAmount
    )
        public
        view
        returns (uint256, uint256)
    {
        IComptroller comptroller = IComptroller(ICToken(cTokenCollateral).comptroller());
        require(address(comptroller) == ICToken(suToken).comptroller(), "not the same comptroller");

        (uint256 liquidity,) = comptroller.getHypotheticalAccountLiquidity(account, cTokenCollateral, 0, 0);
        uint256 maxCBorrowAmount = (liquidity * expScale) / comptroller.getUnderlyingPriceNormalized(cTokenCollateral);

        address[] memory assets = comptroller.getAssetsIn(account);
        (, uint8 suGroupId,) = comptroller.markets(suToken);

        uint256 shortfallMantissa = comptroller.getUnderlyingPriceNormalized(suToken) * suBorrowAmount;
        uint256 liquidityMantissa = 0;

        for (uint256 i = 0; i < assets.length; ++i) {
            address asset = assets[i];
            (, uint8 assetGroupId,) = comptroller.markets(asset);

            // only consider asset in the same group
            if (assetGroupId != suGroupId) {
                continue;
            }

            (uint256 depositBalance, uint256 borrowBalance, uint256 exchangeRateMantissa,) =
                ICToken(asset).getAccountSnapshot(account);

            // get token price
            uint256 tokenPriceMantissa = comptroller.getUnderlyingPriceNormalized(asset);

            uint256 tokenCollateralRateMantissa = getCollateralRate(comptroller, asset, suToken);

            if (asset == suToken) {
                shortfallMantissa = shortfallMantissa + tokenPriceMantissa * borrowBalance;
            } else {
                liquidityMantissa = liquidityMantissa
                    + (tokenPriceMantissa * depositBalance * exchangeRateMantissa * tokenCollateralRateMantissa) / expScale / expScale;
            }
        }
        if (shortfallMantissa <= liquidityMantissa) {
            return (0, maxCBorrowAmount);
        }

        return (
            ((shortfallMantissa - liquidityMantissa) * expScale) / comptroller.getUnderlyingPriceNormalized(cTokenCollateral)
                / getCollateralRate(IComptroller(comptroller), cTokenCollateral, suToken),
            maxCBorrowAmount
        );
    }

    // version is enabled after V3
    function version() external pure returns (Version) {
        return Version.V4;
    }
}
