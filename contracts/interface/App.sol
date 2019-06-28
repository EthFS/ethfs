pragma solidity >= 0.5.8;

import "./Kernel.sol";

interface App {
  function main(Kernel kernel, bytes calldata args) external returns (uint);
}
