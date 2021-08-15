pragma solidity 0.6.7;

import "ds-test/test.sol";

import "../resolver/TellorResolver.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract TellorAggregator {
    uint256 price;
    uint256 age;

    function setAge(uint256 data) external {
        age = data;
    }
    function modifyParameters(bytes32 parameter, uint256 data) external {
        price = data;
    }

    function getCurrentValue(uint256 _requestId) external view returns (bool, uint256, uint256) {
        return (true, price, age);
    }
}

contract TellorResolverTest is DSTest {
    Hevm hevm;

    uint256 age;

    uint256 price          = 1 ether;
    uint256 startTime      = 1577836800;
    uint256 staleThreshold = 6 hours;

    TellorAggregator aggregator;
    TellorResolver resolver;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(startTime);

        age = now;

        aggregator = new TellorAggregator();
        aggregator.setAge(age);
        aggregator.modifyParameters("", price);

        resolver   = new TellorResolver(
          address(aggregator),
          1,
          staleThreshold
        );
    }

    function test_setup() public {
        assertEq(uint(resolver.staleThreshold()), uint(staleThreshold));
        assertEq(address(resolver.tellorMedian()), address(aggregator));
    }



    function test_read() public {
        uint256 price = resolver.read();
        assertEq(price, 1 ether);
    }
    function testFail_read_old_response() public {
        aggregator.setAge(uint32(now - staleThreshold - 1));
        uint256 price = resolver.read();
    }
    function test_read_feed_too_large() public {
        aggregator.modifyParameters("", uint(uint(-1) - 1));
        uint256 price = resolver.read();
        assertEq(price, uint256(uint(-1) - 1));
    }
    function testFail_read_null_feed() public {
        aggregator.modifyParameters("", uint(0));
        uint256 price = resolver.read();
    }
    function test_getResultWithValidity() public {
        (uint256 price, bool valid) = resolver.getResultWithValidity();
        assertEq(price, 1 ether);
        assertTrue(valid);
    }
    function test_getResultWithValidity_old_response() public {
        aggregator.setAge(uint32(now - staleThreshold - 1));

        (uint256 price, bool valid) = resolver.getResultWithValidity();
        assertEq(price, 0);
        assertTrue(!valid);
    }
    function test_getResultWithValidity_feed_too_large() public {
        aggregator.modifyParameters("", uint(uint(-1) - 1));

        (uint256 price, bool valid) = resolver.getResultWithValidity();
        assertEq(price, uint(uint(-1) - 1));
        assertTrue(valid);
    }
    function test_getResultWithValidity_null_feed() public {
        aggregator.modifyParameters("", uint(0));

        (uint256 price, bool valid) = resolver.getResultWithValidity();
        assertEq(price, 0);
        assertTrue(!valid);
    }
}
