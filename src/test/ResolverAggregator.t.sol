pragma solidity 0.6.7;

import "ds-test/test.sol";

import "../resolver/ChainlinkResolver.sol";
import "../resolver/MakerResolver.sol";

import "../ResolverAggregator.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract ChainlinkAggregator {
    int256 public latestAnswer;
    uint256 public latestTimestamp;

    function modifyParameters(bytes32 parameter, uint data) external {
        latestTimestamp = data;
    }
    function modifyParameters(bytes32 parameter, int data) external {
        latestAnswer = data;
    }
}
contract MakerAggregator {
    bool    public valid;
    uint32  public age;
    uint256 public price;

    function setAge(uint32 data) external {
        age = data;
    }
    function modifyParameters(bytes32 parameter, uint256 data) external {
        price = data;
    }
    function modifyParameters(bytes32 parameter, bool data) external {
        valid = data;
    }

    function read() external view returns (uint256) {
        if (valid) return price;
        revert();
    }

    function peek() external view returns (uint256,bool) {
        return (price, valid);
    }
}
contract EmptyAggregator {
    function read() external view returns (uint256) {}
}

contract ResolverAggregatorTest is DSTest {
    Hevm hevm;

    uint256 age;

    uint256 price               = 1 ether;
    uint256 startTime           = 1577836800;
    uint256 staleThreshold      = 6 hours;
    uint256 aggregatorThreshold = 10;

    ChainlinkAggregator chainlinkAggregator;
    ChainlinkResolver chainlinkResolver;

    MakerAggregator makerAggregator;
    MakerResolver makerResolver;

    ResolverAggregator aggregator;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(startTime);

        age = now;

        // Maker
        makerAggregator = new MakerAggregator();
        makerAggregator.setAge(uint32(age));
        makerAggregator.modifyParameters("", price);
        makerAggregator.modifyParameters("", true);

        makerResolver = new MakerResolver(
          address(makerAggregator),
          staleThreshold
        );

        // Chainlink
        chainlinkAggregator = new ChainlinkAggregator();
        chainlinkAggregator.modifyParameters("", now);
        chainlinkAggregator.modifyParameters("", int(price / 1E10));

        chainlinkResolver = new ChainlinkResolver(
          address(chainlinkAggregator),
          10,
          staleThreshold
        );

        // Aggregator
        aggregator = new ResolverAggregator(address(chainlinkResolver), address(makerResolver), aggregatorThreshold);
    }

    function test_setup() public {
        assertEq(aggregator.authorizedAccounts(address(this)), 1);
        assertEq(address(aggregator.coreFeed()), address(chainlinkResolver));
        assertEq(address(aggregator.checkerFeed()), address(makerResolver));
        assertEq(aggregator.threshold(), aggregatorThreshold);
    }
    function test_modify_parameters() public {
        EmptyAggregator empty = new EmptyAggregator();

        aggregator.modifyParameters("coreFeed", address(empty));
        aggregator.modifyParameters("checkerFeed", address(empty));

        assertEq(address(aggregator.coreFeed()), address(empty));
        assertEq(address(aggregator.checkerFeed()), address(empty));
    }

    function testFail_read_invalid_core_feed() public {
        chainlinkAggregator.modifyParameters("", now - staleThreshold - 1);
        aggregator.read();
    }
    function testFail_read_invalid_checker_feed() public {
        makerAggregator.setAge(uint32(now - staleThreshold - 1));
        aggregator.read();
    }
    function testFail_read_null_core_feed() public {
        chainlinkAggregator.modifyParameters("", uint(0));
        aggregator.read();
    }
    function testFail_read_null_checker_feed() public {
        makerAggregator.modifyParameters("", uint(0));
        aggregator.read();
    }
    function testFail_read_exceeds_threshold() public {
        chainlinkAggregator.modifyParameters("", uint(makerAggregator.read()) * 5);
        aggregator.read();
    }
    function test_read_below_threshold() public {
        makerAggregator.modifyParameters("", uint(makerResolver.read() + 10));

        uint256 val = aggregator.read();
        assertEq(val, price);
    }
    function test_read() public {
        uint256 val = aggregator.read();
        assertEq(val, price);
    }

    function test_getResultWithValidity_invalid_core_feed() public {
        chainlinkAggregator.modifyParameters("", now - staleThreshold - 1);

        (uint256 val, bool isValid) = aggregator.getResultWithValidity();
        assertEq(val, 0);
        assertTrue(!isValid);
    }
    function test_getResultWithValidity_invalid_checker_feed() public {
        makerAggregator.setAge(uint32(now - staleThreshold - 1));

        (uint256 val, bool isValid) = aggregator.getResultWithValidity();
        assertEq(val, 0);
        assertTrue(!isValid);
    }
    function test_getResultWithValidity_null_core_feed() public {
        chainlinkAggregator.modifyParameters("", uint(0));

        (uint256 val, bool isValid) = aggregator.getResultWithValidity();
        assertEq(val, 0);
        assertTrue(!isValid);
    }
    function test_getResultWithValidity_null_checker_feed() public {
        makerAggregator.modifyParameters("", uint(0));

        (uint256 val, bool isValid) = aggregator.getResultWithValidity();
        assertEq(val, 0);
        assertTrue(!isValid);
    }
    function test_getResultWithValidity_exceeds_threshold() public {
        chainlinkAggregator.modifyParameters("", int(uint(makerResolver.read()) * 5) / 1E10);

        (uint256 val, bool isValid) = aggregator.getResultWithValidity();
        assertEq(val, 0);
        assertTrue(!isValid);
    }
    function test_getResultWithValidity_below_threshold() public {
        makerAggregator.modifyParameters("", uint(makerResolver.read() + 10));

        (uint256 val, bool isValid) = aggregator.getResultWithValidity();
        assertEq(val, price);
        assertTrue(isValid);
    }
    function test_getResultWithValidity() public {
        (uint256 val, bool isValid) = aggregator.getResultWithValidity();
        assertEq(val, price);
        assertTrue(isValid);
    }

    function testFail_identical_core_checker_read_invalid_feed() public {
        aggregator.modifyParameters("coreFeed", address(chainlinkResolver));
        aggregator.modifyParameters("checkerFeed", address(chainlinkResolver));

        chainlinkAggregator.modifyParameters("", now - staleThreshold - 1);
        aggregator.read();
    }
    function test_identical_core_checker_read() public {
        aggregator.modifyParameters("coreFeed", address(chainlinkResolver));
        aggregator.modifyParameters("checkerFeed", address(chainlinkResolver));

        uint256 val = aggregator.read();
        assertEq(val, price);
    }
}
