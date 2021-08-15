pragma solidity 0.6.7;

import "ds-test/test.sol";

import "../resolver/MakerResolver.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
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

contract MakerResolverTest is DSTest {
    Hevm hevm;

    bool valid             = true;
    uint32 age;

    uint256 price          = 1 ether;
    uint256 startTime      = 1577836800;
    uint256 staleThreshold = 6 hours;

    MakerAggregator aggregator;
    MakerResolver resolver;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(startTime);

        age = uint32(now);

        aggregator = new MakerAggregator();
        aggregator.setAge(age);
        aggregator.modifyParameters("", price);
        aggregator.modifyParameters("", valid);

        resolver   = new MakerResolver(
          address(aggregator),
          staleThreshold
        );
    }

    function test_setup() public {
        assertEq(uint(resolver.staleThreshold()), uint(staleThreshold));
        assertEq(address(resolver.makerMedian()), address(aggregator));
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
    function testFail_read_invalid_maker_response() public {
        aggregator.modifyParameters("", false);
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
    function test_getResultWithValidity_invalid_maker_response() public {
        aggregator.modifyParameters("", false);

        (uint256 price, bool valid) = resolver.getResultWithValidity();
        assertEq(price, 0);
        assertTrue(valid == false);
    }
}
