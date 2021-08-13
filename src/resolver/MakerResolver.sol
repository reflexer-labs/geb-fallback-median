pragma solidity 0.6.7;

import "geb-treasury-reimbursement/math/GebMath.sol";

import "../medians/MakerMedian.sol";

contract MakerResolver is GebMath {
    // --- Variables ---
    MakerMedian public makerMedian;

    // Time threshold after which a Maker response is considered stale
    uint256 public staleThreshold;

    bytes32 public symbol = "ETHUSD";

    constructor(
      address median,
      uint256 staleThreshold_
    ) public {
        require(median != address(0), "MakerResolver/null-median");
        require(staleThreshold_ > 0, "MakerResolver/null-stale-threshold");

        staleThreshold = staleThreshold_;
        makerMedian    = MakerMedian(median);
    }

    // --- General Utils ---
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }

    
}
