pragma solidity 0.6.7;

import "ds-test/test.sol";

import "../resolver/ChainlinkResolver.sol";

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

contract ChainlinkResolverTest is DSTest {
    Hevm hevm;

    uint256 startTime      = 1577836800;
    uint256 staleThreshold = 6 hours;

    ChainlinkAggregator aggregator;
    ChainlinkResolver resolver;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(startTime);

        aggregator = new ChainlinkAggregator();
        aggregator.modifyParameters("", now);
        aggregator.modifyParameters("", int(1 ether / 1E10));

        resolver   = new ChainlinkResolver(
          address(aggregator),
          10,
          staleThreshold
        );
    }

    function test_setup() public {
        assertEq(uint(resolver.multiplier()), uint(10));
        assertEq(uint(resolver.staleThreshold()), uint(staleThreshold));
        assertEq(address(resolver.chainlinkMedian()), address(aggregator));
    }
    function test_read() public {
        uint256 price = resolver.read();
        assertEq(price, 1 ether);
    }
    function testFail_read_old_response() public {
        aggregator.modifyParameters("", now - staleThreshold - 1);
        uint256 price = resolver.read();
    }
    function testFail_read_feed_too_large() public {
        aggregator.modifyParameters("", int(uint(-1) - 1));
        uint256 price = resolver.read();
    }
    function testFail_read_null_feed() public {
        aggregator.modifyParameters("", int(0));
        uint256 price = resolver.read();
    }
    function test_getResultWithValidity() public {
        (uint256 price, bool valid) = resolver.getResultWithValidity();
        assertEq(price, 1 ether);
        assertTrue(valid);
    }
    function test_getResultWithValidity_old_response() public {
        aggregator.modifyParameters("", now - staleThreshold - 1);

        (uint256 price, bool valid) = resolver.getResultWithValidity();
        assertEq(price, 0);
        assertTrue(!valid);
    }
    function test_getResultWithValidity_feed_too_large() public {
        aggregator.modifyParameters("", int(uint(-1) - 1));

        (uint256 price, bool valid) = resolver.getResultWithValidity();
        assertEq(price, 0);
        assertTrue(!valid);
    }
    function test_getResultWithValidity_null_feed() public {
        aggregator.modifyParameters("", int(0));

        (uint256 price, bool valid) = resolver.getResultWithValidity();
        assertEq(price, 0);
        assertTrue(!valid);
    }
}
