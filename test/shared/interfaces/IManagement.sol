// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IManagement {
    function clearCache() external;

    function addAToken(address _underlying, address _aToken) external;

    function addSToken(address _underlying, address _sToken) external;

    function addVToken(address _underlying, address _vToken) external;

    function addLenderTokens(address _underlying, address _aToken, address _vToken, address _sToken) external;

    function addGeneralLenderTokens(
        address _underlying,
        address _aToken,
        address _vToken,
        address _sToken,
        uint16 _lenderId //
    )
        external;

    function setValidTarget(address _target, bool value) external;

    function approveLendingPool(address[] memory assets) external;

    function approveAddress(address[] memory assets, address target) external;

    struct BatchAddLenderTokensParams {
        address underlying;
        address collateralToken;
        address debtToken;
        address stableDebtToken;
        uint16 lenderId;
    }

    function batchAddGeneralLenderTokens(
        BatchAddLenderTokensParams[] memory lenderParams //
    )
        external;

    struct ApproveParams {
        address token;
        address target;
    }

    function batchApprove(ApproveParams[] memory assets) external;

    function decreaseAllowance(address[] memory assets, address target) external;

    function getLendingPool(uint16 _lenderId) external view returns (address pool);

    function getAToken(address _underlying) external view returns (address);

    function getSToken(address _underlying) external view returns (address);

    function getVToken(address _underlying) external view returns (address);

    function getIsValidTarget(address _target) external view returns (bool);

    function getCollateralToken(address _underlying, uint16 _lenderId) external view returns (address);

    function getStableDebtToken(address _underlying, uint16 _lenderId) external view returns (address);

    function getDebtToken(address _underlying, uint16 _lenderId) external view returns (address);

    function addLendingPool(
        address _poolAddress,
        uint16 _lenderId //
    )
        external;
}
