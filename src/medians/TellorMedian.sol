pragma solidity 0.6.7;

interface TellorMedian {
    function getCurrentValue(uint256 _requestId) external view returns (bool ifRetrieve, uint256 value, uint256 _timestampRetrieved);
}
