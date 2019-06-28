pragma solidity >= 0.5.8;

import "../interface/App.sol";

contract Move is App {
  constructor(Kernel kernel) public {
    kernel.linkContract(address(this), '/bin/mv');
  }

  function main(Kernel kernel, bytes calldata args) external returns (uint) {
    kernel.link(args, args);
    kernel.unlink(args);
    return 0;
  }
}
