pragma solidity >= 0.5.8;

import './interface/Kernel.sol';

contract SetupDirs {
  constructor(Kernel kernel) public {
    kernel.mkdir('/bin');
  }
}
