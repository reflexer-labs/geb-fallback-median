pragma solidity 0.6.7;

import "./math/GebMath.sol";

import "./interfaces/ResolverLike.sol";

contract ResolverAggregator is GebMath {
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
        require(authorizedAccounts[msg.sender] == 1, "ResolverAggregator/account-not-authorized");
        _;
    }

    // --- Variables ---
    // Threshold difference between the core and the checker prices above which this aggregator will deem the feeds invalid
    uint256      public threshold;

    // The main feed to pull prices from
    ResolverLike public coreFeed;
    // The checker feed used to sanitize the core one
    ResolverLike public checkerFeed;

    // --- Events ---
    event AddAuthorization(address account);
    event RemoveAuthorization(address account);
    event ModifyParameters(
      bytes32 parameter,
      address addr
    );

    constructor(
      address coreFeed_,
      address checkerFeed_,
      uint256 threshold_
    ) public {
        require(both(threshold_ > 0, threshold_ < HUNDRED), "ResolverAggregator/invalid-threshold");
        require(coreFeed_ != address(0), "ResolverAggregator/null-core-feed");
        require(checkerFeed_ != address(0), "ResolverAggregator/null-checker-feed");

        authorizedAccounts[msg.sender] = 1;

        threshold    = threshold_;
        coreFeed     = ResolverLike(coreFeed_);
        checkerFeed  = ResolverLike(checkerFeed_);

        emit ModifyParameters(
          "coreFeed",
          coreFeed_
        );
        emit ModifyParameters(
          "checkerFeed",
          checkerFeed_
        );
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
    * @notice Change one of the feeds
    * @param parameter The name of the feed to change
    * @param val The new address for the feed
    **/
    function modifyParameters(bytes32 parameter, address val) external isAuthorized {
        require(val != address(0), "ResolverAggregator/null-address");

        if (parameter == "coreFeed") {
          coreFeed = ResolverLike(val);
          coreFeed.read();
        } else if (parameter == "checkerFeed") {
          checkerFeed = ResolverLike(val);
          checkerFeed.read();
        } else revert("ResolverAggregator/modify-unrecognized-param");

        emit ModifyParameters(parameter, val);
    }

    // --- Main Getters ---
    /**
    * @notice Return the median result by checking the percentage delta between both the core and the checker prices.
    *         Revert if feeds return 0 or if the percentage delta is too large
    **/
    function read() external view returns (uint256) {
        // Fetch values from both feeds
        uint256 coreMedianPrice    = coreFeed.read();
        uint256 checkerMedianPrice = checkerFeed.read();

        require(both(coreMedianPrice > 0, checkerMedianPrice > 0), "ResolverAggregator/invalid-prices");

        // Calculate the % difference between the two prices
        uint256 percentageDelta = multiply(delta(coreMedianPrice, checkerMedianPrice), HUNDRED) / coreMedianPrice;

        require(percentageDelta <= threshold, "ResolverAggregator/exceeds-threshold-difference");
        return coreMedianPrice;
    }
    /**
    * @notice Return the median result by checking the percentage delta between both the core and the checker prices.
    **/
    function getResultWithValidity() external view returns (uint256, bool) {
        // Fetch values from both feeds
        (uint256 coreMedianPrice, bool coreIsValid)       = coreFeed.getResultWithValidity();
        (uint256 checkerMedianPrice, bool checkerIsValid) = checkerFeed.getResultWithValidity();

        if (
          either(
            either(coreMedianPrice == 0, !coreIsValid), either(checkerMedianPrice == 0, !checkerIsValid)
          )
        ) {
          return (0, false);
        }

        // Calculate the % difference between the two prices
        uint256 percentageDelta = multiply(delta(coreMedianPrice, checkerMedianPrice), HUNDRED) / coreMedianPrice;

        if (percentageDelta <= threshold) {
          return (coreMedianPrice, true);
        }

        return (0, false);
    }
}
