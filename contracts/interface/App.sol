pragma solidity >= 0.5.8;

import "./Kernel.sol";

interface App {
  function main(Kernel kernel, bytes32[] calldata arg1, bytes32[] calldata arg2) external returns (uint);
}
