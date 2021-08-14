pragma solidity 0.6.7;

import "../math/GebMath.sol";

import "../medians/ChainlinkMedian.sol";

contract ChainlinkResolver is GebMath {
    // --- Variables ---
    ChainlinkMedian public chainlinkMedian;

    // Multiplier for the Chainlink price feed in order to scaled it to 18 decimals. Default to 10 for USD price feeds
    uint8   public multiplier = 10;
    // Time threshold after which a Chainlink response is considered stale
    uint256 public staleThreshold;

    bytes32 public symbol = "ETHUSD";

    constructor(
      address median,
      uint8   multiplier_,
      uint256 staleThreshold_
    ) public {
        require(median != address(0), "ChainlinkResolver/null-median");
        require(multiplier_ >= 1, "ChainlinkResolver/null-multiplier");
        require(staleThreshold_ > 0, "ChainlinkResolver/null-stale-threshold");

        multiplier      = multiplier_;
        staleThreshold  = staleThreshold_;
        chainlinkMedian = ChainlinkMedian(median);
    }

    // --- General Utils ---
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }

    // --- Main Getters ---
    /**
    * @notice Fetch the latest medianResult or revert if is is null, if the price is stale or if chainlinkMedian is null
    **/
    function read() external view returns (uint256) {
        // The relayer must not be null
        require(address(chainlinkMedian) != address(0), "ChainlinkResolver/null-median");

        // Fetch values from Chainlink
        uint256 medianPrice     = multiply(uint(chainlinkMedian.latestAnswer()), 10 ** uint(multiplier));
        uint256 medianTimestamp = chainlinkMedian.latestTimestamp();

        require(both(medianPrice > 0, subtract(now, medianTimestamp) <= staleThreshold), "ChainlinkResolver/invalid-price-feed");
        return medianPrice;
    }
    /**
    * @notice Fetch the latest medianResult and whether it is valid or not
    **/
    function getResultWithValidity() external view returns (uint256, bool) {
        if (address(chainlinkMedian) == address(0)) return (0, false);

        // Fetch values from Chainlink
        uint256 medianPrice     = multiply(uint(chainlinkMedian.latestAnswer()), 10 ** uint(multiplier));
        uint256 medianTimestamp = chainlinkMedian.latestTimestamp();

        return (medianPrice, both(medianPrice > 0, subtract(now, medianTimestamp) <= staleThreshold));
    }
}
