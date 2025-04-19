// SPDX-License-Identifier: NONE
pragma solidity ^0.8.28;

interface IComposerLike {
    function deltaCompose(bytes calldata) external payable;

    function onMorphoFlashLoan(uint256, bytes calldata params) external;

    function onMorphoSupply(uint256, bytes calldata params) external;

    function onencodeMorphoRepay(uint256, bytes calldata params) external;

    function onMorphoSupplyCollateral(uint256, bytes calldata params) external;

    function balancerUnlockCallback(bytes calldata) external;

    function unlockCallback(bytes calldata) external;

    function executeOperation(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata, // we assume that the data is known to the caller in advance
        address initiator,
        bytes calldata params
    )
        external
        returns (bool);

    function executeOperation(
        address,
        uint256,
        uint256,
        address initiator,
        bytes calldata params // user params
    )
        external
        returns (bool);

    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    )
        external;
}
