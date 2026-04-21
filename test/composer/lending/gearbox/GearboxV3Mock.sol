// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @dev Minimal Gearbox V3 facade mock — just enough to verify the composer's MultiCall[]
///      encoding. Records every `botMulticall` / `openCreditAccount` input plus the resulting
///      `balanceOf(underlying, this)` for supply/repay tests.
struct MultiCall {
    address target;
    bytes callData;
}

interface IMintable {
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract GearboxV3FacadeMock {
    address public creditManager;
    address public creditAccount; // single CA per mock

    // Last call capture
    bool public lastKindOpen;
    address public lastCaller;
    address public lastCa;
    address public lastOnBehalfOf;
    uint256 public lastRefCode;
    MultiCall[] internal _lastCalls;

    // Per-op records
    struct RecordedOp {
        bytes4 selector;
        bytes args;
    }

    RecordedOp[] internal _ops;

    constructor(address cm, address ca) {
        creditManager = cm;
        creditAccount = ca;
    }

    function lastCallsLength() external view returns (uint256) {
        return _lastCalls.length;
    }

    function getLastCall(uint256 i) external view returns (address target, bytes memory callData) {
        return (_lastCalls[i].target, _lastCalls[i].callData);
    }

    function opsLength() external view returns (uint256) {
        return _ops.length;
    }

    function getOp(uint256 i) external view returns (bytes4 selector, bytes memory args) {
        return (_ops[i].selector, _ops[i].args);
    }

    function clear() external {
        delete _lastCalls;
        delete _ops;
        lastKindOpen = false;
        lastCaller = address(0);
        lastCa = address(0);
        lastOnBehalfOf = address(0);
        lastRefCode = 0;
    }

    function _record(MultiCall[] calldata calls) internal {
        delete _lastCalls;
        for (uint256 i = 0; i < calls.length; i++) {
            _lastCalls.push(MultiCall({target: calls[i].target, callData: calls[i].callData}));
            bytes4 sel = bytes4(calls[i].callData);
            _ops.push(RecordedOp({selector: sel, args: _slice(calls[i].callData, 4, calls[i].callData.length - 4)}));
        }
    }

    function _slice(bytes memory src, uint256 start, uint256 len) private pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = src[start + i];
        }
    }

    function botMulticall(address ca, MultiCall[] calldata calls) external {
        lastKindOpen = false;
        lastCaller = msg.sender;
        lastCa = ca;
        _record(calls);

        // Simulate addCollateral token pulls and withdrawCollateral transfers where possible.
        // The test's mock underlying implements IMintable and the mock holds the CA "balance"
        // internally — modeled as a simple escrow mapping below.
        _settleCalls(calls);
    }

    function openCreditAccount(
        address onBehalfOf,
        MultiCall[] calldata calls,
        uint256 referralCode
    )
        external
        payable
        returns (address newCa)
    {
        lastKindOpen = true;
        lastCaller = msg.sender;
        lastOnBehalfOf = onBehalfOf;
        lastRefCode = referralCode;
        newCa = creditAccount;
        lastCa = newCa;
        _record(calls);
        _settleCalls(calls);
    }

    // CA escrow: internally track token balances that flowed in via addCollateral.
    mapping(address => uint256) public caBalances;
    uint256 public debt;

    /// @dev Dummy "pool" address — decreaseDebt moves underlying from the facade to this address
    ///      so it leaves the facade's tracked balance (mirrors the real Gearbox pool separation).
    address public constant POOL_SINK = address(0xD00D);

    /// @dev Test helpers — explicit setters for state that tests seed directly instead of via
    ///      the composer-facing flow.
    function setCaBalance(address tok, uint256 amt) external {
        caBalances[tok] = amt;
    }

    function setDebt(uint256 amt) external {
        debt = amt;
    }

    function _settleCalls(MultiCall[] calldata calls) internal {
        for (uint256 i = 0; i < calls.length; i++) {
            bytes4 sel = bytes4(calls[i].callData);
            bytes memory body = _slice(calls[i].callData, 4, calls[i].callData.length - 4);
            if (sel == 0x6d75b9ee) {
                // addCollateral(address,uint256) — pull from msg.sender (composer)
                (address tok, uint256 amt) = abi.decode(body, (address, uint256));
                IMintable(tok).transferFrom(msg.sender, address(this), amt);
                caBalances[tok] += amt;
            } else if (sel == 0x2b7c7b11) {
                // increaseDebt(uint256) — we model as incrementing tracked debt and handing
                // underlying to the CA escrow.
                uint256 amt = abi.decode(body, (uint256));
                debt += amt;
                // The test funds the mock with "pool liquidity" of underlying upfront.
                caBalances[mockUnderlying] += amt;
            } else if (sel == 0x2a7ba1f7) {
                // decreaseDebt(uint256) — cap at current debt + CA balance, then move the
                // underlying out of the facade to the dummy pool sink (mirrors the real CM's
                // CA→pool transfer so the facade's token balance matches its caBalances accounting).
                uint256 amt = abi.decode(body, (uint256));
                uint256 cap = debt;
                if (amt > cap) amt = cap;
                if (caBalances[mockUnderlying] < amt) amt = caBalances[mockUnderlying];
                caBalances[mockUnderlying] -= amt;
                debt -= amt;
                if (amt != 0) {
                    IMintable(mockUnderlying).transfer(POOL_SINK, amt);
                }
            } else if (sel == 0x1f1088a0) {
                // withdrawCollateral(address,uint256,address)
                (address tok, uint256 amt, address to) = abi.decode(body, (address, uint256, address));
                if (amt == type(uint256).max) amt = caBalances[tok];
                if (caBalances[tok] < amt) amt = caBalances[tok];
                caBalances[tok] -= amt;
                IMintable(tok).transfer(to, amt);
            }
            // setFullCheckParams / updateQuota — no-op in mock
        }
    }

    address public mockUnderlying;

    function setMockUnderlying(address u) external {
        mockUnderlying = u;
    }
}
