pragma solidity 0.6.7;

import "../math/GebMath.sol";

import "../medians/TellorMedian.sol";

contract TellorResolver is GebMath {
    // --- Variables ---
    TellorMedian public tellorMedian;

    // Time threshold after which a Tellor response is considered stale
    uint256 public staleThreshold;
    // Id used to fetch the price we need from Tellor
    uint256 public requestId;
    // How far in the past is the price that the contract requests
    uint256 public delay;

    bytes32 public symbol = "ETHUSD";

    uint256 public constant MAX_DELAY = 6 hours;

    constructor(
      address median,
      uint256 delay_,
      uint256 requestId_,
      uint256 staleThreshold_
    ) public {
        require(median != address(0), "TellorResolver/null-median");
        require(staleThreshold_ > 0, "TellorResolver/null-stale-threshold");
        require(both(delay_ > 0, delay_ <= MAX_DELAY), "TellorResolver/invalid-delay");

        requestId       = requestId_;
        delay           = delay_;
        staleThreshold  = staleThreshold_;
        tellorMedian    = TellorMedian(median);
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
        require(address(tellorMedian) != address(0), "TellorResolver/null-median");

        // Fetch values from Tellor
        try tellorMedian.retrieveData(requestId, subtract(now, delay))
            returns (bool ifRetrieve, uint256 medianPrice, uint256 medianTimestamp) {
          require(ifRetrieve, "TellorResolver/faulty-retrieval");
          require(both(medianPrice > 0, subtract(now, medianTimestamp) <= staleThreshold), "TellorResolver/invalid-price-feed");
          return medianPrice;
        } catch (bytes memory revertReason) {
          revert();
        }
    }
    /**
    * @notice Fetch the latest medianResult and whether it is valid or not
    **/
    function getResultWithValidity() external view returns (uint256, bool) {
        if (address(tellorMedian) == address(0)) return (0, false);

        // Fetch values from Tellor
        try tellorMedian.retrieveData(requestId, subtract(now, delay))
            returns (bool ifRetrieve, uint256 medianPrice, uint256 medianTimestamp) {
          // Check validity and set price accordingly
          bool valid  = both(medianPrice > 0, subtract(now, medianTimestamp) <= staleThreshold);
          medianPrice = both(valid, ifRetrieve) ? medianPrice : 0;

          return (medianPrice, both(valid, ifRetrieve));
        } catch (bytes memory revertReason) {
          return (0, false);
        }
    }
}
