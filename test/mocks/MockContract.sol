// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

error ShouldRevert();

contract MockContract {
    bool public shouldFail;
    bool public called;
    bool public catchCalled;

    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }

    function testCall() external {
        called = true;

        if (shouldFail) {
            revert ShouldRevert();
        }
    }

    function catchBlock() external {
        catchCalled = true;
    }

    function reset() external {
        called = false;
        catchCalled = false;
    }
}

