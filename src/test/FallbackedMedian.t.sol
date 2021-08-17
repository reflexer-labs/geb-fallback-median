pragma solidity 0.6.7;

import "ds-test/test.sol";

import "../resolver/ChainlinkResolver.sol";
import "../resolver/MakerResolver.sol";
import "../resolver/TellorResolver.sol";

import "../ResolverAggregator.sol";
import "../FallbackedMedian.sol";

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
contract TellorAggregator {
    uint256 price;
    uint256 age;

    bool ifRetrieve = true;

    function setAge(uint256 data) external {
        age = data;
    }
    function toggleRetrieve() external {
        ifRetrieve = !ifRetrieve;
    }
    function modifyParameters(bytes32 parameter, uint256 data) external {
        price = data;
    }

    function retrieveData(uint256 _requestId, uint256) external view returns (bool, uint256, uint256) {
        return (ifRetrieve, price, age);
    }
}
contract EmptyAggregator {
    function read() external view returns (uint256) {}
}

contract FallbackedMedianTest is DSTest {
    Hevm hevm;

    uint256 age;

    uint256 price               = 1 ether;
    uint256 startTime           = 1577836800;
    uint256 staleThreshold      = 6 hours;
    uint256 delay               = 30 minutes;
    uint256 aggregatorThreshold = 10;

    ChainlinkAggregator chainlinkAggregator;
    ChainlinkResolver chainlinkResolver;

    MakerAggregator makerAggregator;
    MakerResolver makerResolver;

    TellorAggregator tellorAggregator;
    TellorResolver tellorResolver;

    ResolverAggregator aggregator;
    FallbackedMedian fallbackMedian;

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

        // Tellor
        tellorAggregator = new TellorAggregator();
        tellorAggregator.setAge(age);
        tellorAggregator.modifyParameters("", price);

        tellorResolver = new TellorResolver(
          address(tellorAggregator),
          delay,
          1,
          staleThreshold
        );

        // Aggregator
        aggregator = new ResolverAggregator(address(chainlinkResolver), address(makerResolver), aggregatorThreshold);

        // Fallback median
        fallbackMedian = new FallbackedMedian(address(tellorResolver), address(aggregator));
    }

    function test_setup() public {
        assertEq(address(fallbackMedian.fallbackFeed()), address(tellorResolver));
        assertEq(address(fallbackMedian.aggregator()), address(aggregator));
    }
    function test_modify_parameters() public {
        EmptyAggregator empty = new EmptyAggregator();

        fallbackMedian.modifyParameters("fallbackFeed", address(empty));
        fallbackMedian.modifyParameters("aggregator", address(empty));

        assertEq(address(fallbackMedian.fallbackFeed()), address(empty));
        assertEq(address(fallbackMedian.aggregator()), address(empty));
    }
    function test_read() public {
        uint256 retrievedPrice = fallbackMedian.read();
        assertEq(price, retrievedPrice);
    }
    function test_read_fallback_used_core_faulty() public {
        chainlinkAggregator.modifyParameters("", int(0));
        uint256 retrievedPrice = fallbackMedian.read();
        assertEq(price, retrievedPrice);
    }
    function test_read_fallback_used_checker_faulty() public {
        makerAggregator.modifyParameters("", false);
        uint256 retrievedPrice = fallbackMedian.read();
        assertEq(price, retrievedPrice);
    }
    function testFail_read_fallback_used_null() public {
        makerAggregator.modifyParameters("", false);
        tellorAggregator.modifyParameters("", uint(0));
        uint256 retrievedPrice = fallbackMedian.read();
    }
    function test_getResultWithValidity() public {
        (uint256 retrievedPrice, bool valid) = fallbackMedian.getResultWithValidity();
        assertEq(price, retrievedPrice);
        assertTrue(valid);
    }
    function test_getResultWithValidity_fallback_used_core_faulty() public {
        chainlinkAggregator.modifyParameters("", int(0));

        (uint256 retrievedPrice, bool valid) = fallbackMedian.getResultWithValidity();
        assertEq(price, retrievedPrice);
        assertTrue(valid);
    }
    function test_getResultWithValidity_fallback_used_checker_faulty() public {
        makerAggregator.modifyParameters("", false);

        (uint256 retrievedPrice, bool valid) = fallbackMedian.getResultWithValidity();
        assertEq(price, retrievedPrice);
        assertTrue(valid);
    }
    function test_getResultWithValidity_fallback_used_null() public {
        makerAggregator.modifyParameters("", false);
        tellorAggregator.modifyParameters("", uint(0));

        (uint256 retrievedPrice, bool valid) = fallbackMedian.getResultWithValidity();
        assertEq(0, retrievedPrice);
        assertTrue(!valid);
    }
}
