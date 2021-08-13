pragma solidity 0.6.7;

interface ResolverLike {
    function getResultWithValidity() external view returns (uint256,bool);
    function read() external view returns (uint256);
}
