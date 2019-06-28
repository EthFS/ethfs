pragma solidity >= 0.5.8;

import "./interface/App.sol";

contract TestDapp is App {
  constructor(Kernel kernel) public {
    kernel.linkContract(address(this), '/bin/TestDapp');
  }

  function main(Kernel kernel, bytes calldata) external returns (uint) {
    uint fd = kernel.open('test_file', 0x0101);
    kernel.write(fd, 'foo', 'bar');
    kernel.close(fd);
    return 0;
  }
}
