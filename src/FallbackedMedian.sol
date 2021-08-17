pragma solidity 0.6.7;

import "./math/GebMath.sol";
import "./interfaces/ResolverLike.sol";

import "./ResolverAggregator.sol";

contract FallbackedMedian is GebMath {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    /**
     * @notice Add auth to an account
     * @param account Account to add auth to
     */
    function addAuthorization(address account) virtual external isAuthorized {
        authorizedAccounts[account] = 1;
        emit AddAuthorization(account);
    }
    /**
     * @notice Remove auth from an account
     * @param account Account to remove auth from
     */
    function removeAuthorization(address account) virtual external isAuthorized {
        authorizedAccounts[account] = 0;
        emit RemoveAuthorization(account);
    }
    /**
    * @notice Checks whether msg.sender can call an authed function
    **/
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "FallbackedMedian/account-not-authorized");
        _;
    }

    // --- Variables ---
    // The fallback feed to pull prices from
    ResolverLike       public fallbackFeed;
    // Resolver aggregator handling the core and checker feeds
    ResolverAggregator public aggregator;

    // --- Events ---
    event AddAuthorization(address account);
    event RemoveAuthorization(address account);
    event ModifyParameters(
      bytes32 parameter,
      address addr
    );

    constructor(
      address fallbackFeed_,
      address aggregator_
    ) public {
        require(fallbackFeed_ != address(0), "FallbackedMedian/null-fallback-feed");
        require(aggregator_ != address(0), "FallbackedMedian/null-aggregator");

        authorizedAccounts[msg.sender] = 1;

        aggregator   = ResolverAggregator(aggregator_);
        fallbackFeed = ResolverLike(fallbackFeed_);

        emit ModifyParameters("aggregator", aggregator_);
        emit ModifyParameters("fallbackFeed", fallbackFeed_);
    }

    // --- Boolean Utils ---
    function either(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := or(x, y)}
    }
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }

    // --- Administration ---
    /**
    * @notice Change an address parameter
    * @param parameter The name of the parameter to change
    * @param val The new address for the parameter
    **/
    function modifyParameters(bytes32 parameter, address val) external isAuthorized {
        require(val != address(0), "FallbackedMedian/null-address");

        if (parameter == "fallbackFeed") {
          fallbackFeed = ResolverLike(val);
          fallbackFeed.read();
        } else if (parameter == "aggregator") {
          aggregator = ResolverAggregator(val);
        } else revert("FallbackedMedian/modify-unrecognized-param");

        emit ModifyParameters(parameter, val);
    }

    // --- Main Getters ---
    /**
    * @notice Return the median result by checking the aggregator result first. If the aggregator result is faulty, use the fallback instead
    **/
    function read() external view returns (uint256) {
        // Fetch the aggregator value
        try aggregator.read() returns (uint256 aggregatorPrice) {
          if (aggregatorPrice == 0) {
            // Fetch the fallback price
            uint256 fallbackPrice = fallbackFeed.read();
            require(fallbackPrice > 0, "FallbackedMedian/both-prices-null");
            return fallbackPrice;
          }

          return aggregatorPrice;
        } catch (bytes memory revertReason) {
          // Fetch the fallback price
          uint256 fallbackPrice = fallbackFeed.read();
          require(fallbackPrice > 0, "FallbackedMedian/both-prices-null");
          return fallbackPrice;
        }
    }
    /**
    * @notice Return the median result checking the aggregator result first. If the aggregator result is faulty, use the fallback instead
    **/
    function getResultWithValidity() external view returns (uint256, bool) {
        // Fetch the aggregator value
        (uint256 aggregatorPrice, bool aggregatorIsValid) = aggregator.getResultWithValidity();

        if (either(aggregatorPrice == 0, !aggregatorIsValid)) {
          // Fetch the fallback price
          (uint256 fallbackPrice, bool fallbackIsValid) = fallbackFeed.getResultWithValidity();

          if (both(fallbackPrice > 0, fallbackIsValid)) {
            return (fallbackPrice, true);
          }

          return (0, false);
        } else {
          return (aggregatorPrice, true);
        }
    }

    // --- Median Updates ---
    /*
    * @notice Remnant from older medians
    */
    function updateResult(address feeReceiver) external {}
}
