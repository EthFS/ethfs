pragma solidity >= 0.5.9;

import "./interface/Kernel.sol";

contract TestDapp {
  function main(Kernel kernel) public returns (uint) {
    bytes32[] memory path = new bytes32[](1);
    path[0] = "test_file";
    uint fd = kernel.open(path, 0x0001 | 0x0200);
    kernel.write(fd, "foo", "bar");
    kernel.close(fd);
    return 0;
  }
}
