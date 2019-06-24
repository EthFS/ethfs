pragma solidity >= 0.5.8;

import "./Kernel.sol";

interface App {
  function main(Kernel kernel, bytes32[] calldata args) external returns (uint);
}
