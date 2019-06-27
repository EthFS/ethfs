pragma solidity >= 0.5.8;

import "../interface/App.sol";

contract Move is App {
  constructor(Kernel kernel) public {
    bytes32[] memory path = new bytes32[](3);
    path[1] = "bin";
    path[2] = "mv";
    kernel.linkContract(address(this), path);
  }

  function main(Kernel kernel, bytes32[] calldata arg1, bytes32[] calldata arg2) external returns (uint) {
    kernel.link(arg1, arg2);
    kernel.unlink(arg1);
    return 0;
  }
}
