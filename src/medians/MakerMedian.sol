pragma solidity 0.6.7;

interface MakerMedian {
    function peek() external view returns (uint256,bool);
}
