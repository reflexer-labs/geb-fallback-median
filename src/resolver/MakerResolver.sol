pragma solidity 0.6.7;

import "../math/GebMath.sol";

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

    // --- Main Getters ---
    /**
    * @notice Fetch the latest medianResult or revert if is is null, if the price is stale or if makerMedian is null
    **/
    function read() external view returns (uint256) {
        // The relayer must not be null
        require(address(makerMedian) != address(0), "MakerResolver/null-median");

        // Fetch values from mAKER
        uint256 medianPrice      = makerMedian.read();
        uint256 medianTimestamp  = uint256(makerMedian.age());

        require(both(medianPrice > 0, subtract(now, medianTimestamp) <= staleThreshold), "MakerResolver/invalid-price-feed");
        return medianPrice;
    }
    /**
    * @notice Fetch the latest medianResult and whether it is valid or not
    **/
    function getResultWithValidity() external view returns (uint256, bool) {
        if (address(makerMedian) == address(0)) return (0, false);

        // Fetch values from Maker
        (uint256 medianPrice, bool isValid) = makerMedian.peek();
        uint256 medianTimestamp             = uint256(makerMedian.age());

        // Check validity and set price accordingly
        bool valid  = both(both(medianPrice > 0, subtract(now, medianTimestamp) <= staleThreshold), isValid);
        medianPrice = (valid) ? medianPrice : 0;

        return (medianPrice, valid);
    }
}
