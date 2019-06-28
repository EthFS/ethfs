pragma solidity >= 0.5.8;

import './Kernel.sol';

interface App {
  function main(Kernel kernel, uint[] calldata argi, bytes calldata args) external returns (uint);
}
