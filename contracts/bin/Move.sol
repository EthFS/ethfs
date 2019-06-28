pragma solidity >= 0.5.8;

import '../interface/App.sol';

contract Move is App {
  constructor(Kernel kernel) public {
    kernel.install(address(this), '/bin/mv');
  }

  function main(Kernel kernel, uint[] calldata argi, bytes calldata args) external returns (uint) {
    require(argi.length == 2, 'EINVAL');
    bytes memory arg1 = new bytes(argi[0]);
    bytes memory arg2 = new bytes(argi[1] - argi[0]);
    for (uint i = 0; i < arg1.length; i++) arg1[i] = args[i];
    for (uint i = 0; i < arg2.length; i++) arg2[i] = args[i + argi[0]];
    kernel.link(arg1, arg2);
    kernel.unlink(arg1);
  }
}
