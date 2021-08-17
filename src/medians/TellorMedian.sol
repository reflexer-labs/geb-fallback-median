pragma solidity 0.6.7;

interface TellorMedian {
    function retrieveData(uint _requestId, uint _timestamp) view external returns (bool ifRetrieve, uint256 value, uint256 _timestampRetrieved);
}
