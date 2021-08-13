pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebFallbackMedian.sol";

contract GebFallbackMedianTest is DSTest {
    GebFallbackMedian median;

    function setUp() public {
        median = new GebFallbackMedian();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}