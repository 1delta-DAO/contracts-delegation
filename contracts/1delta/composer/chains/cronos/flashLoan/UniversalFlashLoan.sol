/**
 * @title Flash loan aggregator
 * @author 1delta Labs AG
 */
contract UniversalFlashLoan {
    /**
     * Empty flash loaner
     */
    function _universalFlashLoan(uint256 currentOffset, address callerAddress) internal virtual returns (uint256) {
        assembly {
            revert(0, 0)
        }
    }
}
