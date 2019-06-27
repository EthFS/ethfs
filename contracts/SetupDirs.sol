pragma solidity >= 0.5.8;

import "./interface/Kernel.sol";

contract SetupDirs {
  constructor(Kernel kernel) public {
    bytes32[] memory path = new bytes32[](2);
    path[1] = "bin";
    kernel.mkdir(path);
  }
}
