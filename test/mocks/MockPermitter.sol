// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockPermitter {
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

    bool public isAuth;

    function setAuthorizationWithSig(Authorization calldata authorization, Signature calldata signature) external {
        isAuth = true;
    }

    function getIsAuth() external view returns (bool) {
        return isAuth;
    }
}

