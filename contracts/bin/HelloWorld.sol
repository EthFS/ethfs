pragma solidity >= 0.5.8;

import '../interface/App.sol';

contract HelloWorld is App {
  function main(Kernel kernel, uint[] calldata, bytes calldata) external returns (uint) {
    uint fd = kernel.open('hello_world.txt', 0x0101);
    kernel.write(fd, 'Hello', 'World!');
    kernel.close(fd);
  }
}
