pragma solidity >= 0.5.8;

import "../interface/App.sol";

contract TestDapp is App {
  constructor(Kernel kernel) public {
    bytes32[] memory path = new bytes32[](1);
    path[0] = "TestDapp";
    kernel.linkContract(address(this), path);
  }

  function main(Kernel kernel, bytes32[] calldata) external returns (uint) {
    bytes32[] memory path = new bytes32[](1);
    path[0] = "test_file";
    uint fd = kernel.open(path, 0x0001 | 0x0200);
    kernel.write(fd, "foo", "bar");
    kernel.close(fd);
    return 0;
  }
}
