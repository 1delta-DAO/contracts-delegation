// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/modules/shared/MetaAggregator.sol";
import "../../contracts/1delta/test/MockERC20WithPermit.sol";
import "../../contracts/1delta/test/TrivialMockRouter.sol";

struct Authorization {
    address authorizer;
    address authorized;
    bool isAuthorized;
    uint256 nonce;
    uint256 deadline;
}

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

interface ICometExt {
    function allowBySig(
        address owner,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry,
        uint8 v, //
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Sets the authorization for `authorization.authorized` to manage `authorization.authorizer`'s positions.
    /// @dev Warning: Reverts if the signature has already been submitted.
    /// @dev The signature is malleable, but it has no impact on the security here.
    /// @dev The nonce is passed as argument to be able to revert with a different error message.
    /// @param authorization The `Authorization` struct.
    /// @param signature The signature.
    function setAuthorizationWithSig(Authorization calldata authorization, Signature calldata signature) external;
}

contract Nothing is ICometExt {
    uint public signed = 0;
    uint public signedMorpho = 0;

    function call() external {}

    function allowBySig(
        address owner,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry,
        uint8 v, //
        bytes32 r,
        bytes32 s
    ) external override {
        signed++;
    }

    function setAuthorizationWithSig(Authorization calldata authorization, Signature calldata signature) external {
        signedMorpho++;
    }
}

contract ComposerPermitTest is DeltaSetup {
    uint256 constant ERC20_PERMIT_LENGTH = 224;
    uint256 constant COMPACT_ERC20_PERMIT_LENGTH = 100;
    uint256 constant DAI_LIKE_PERMIT_LENGTH = 256;
    uint256 constant COMPACT_DAI_LIKE_PERMIT_LENGTH = 72;
    uint256 constant PERMIT2_LENGTH = 352;
    uint256 constant COMPACT_PERMIT2_LENGTH = 96;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    function test_comet_permit() external {
        address user = testUser;
        vm.assume(user != address(0));
        Nothing _swapTarget = new Nothing();

        bytes memory d = encodeCometPermit(999, true);
        uint16 len = uint16(d.length);

        bytes memory data = abi.encodePacked(uint8(Commands.EXEC_COMPOUND_V3_PERMIT), address(_swapTarget), len, d);

        vm.startPrank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        vm.stopPrank();

        assertEq(_swapTarget.signed(), 1);
    }


    uint256 internal constant SWEEP = 1 << 255;

    function encodeAsset(address asset, bool sweep) private pure returns (bytes32 data) {
        uint256 _data = uint160(asset);
        if (sweep) _data = (_data & ~SWEEP) | SWEEP;
        data = bytes32(_data);
    }

    function encodeCometPermit(uint256 nonce, bool allow) private pure returns (bytes memory) {
        uint256 _data = uint160(nonce);
        if (allow) _data = (_data & ~SWEEP) | SWEEP;

        return
            abi.encodePacked(
                _data,
                uint32(423),
                uint256(674321764327), //
                uint256(943209784329784327982)
            );
    }
}
