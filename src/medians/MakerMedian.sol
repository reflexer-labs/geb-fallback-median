pragma solidity 0.6.7;

interface MakerMedian {
    function age() public view returns (uint32);
    function read() external view returns (uint256);
    function peek() external view returns (uint256,bool);
}
