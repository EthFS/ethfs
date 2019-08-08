pragma solidity >= 0.5.8;

import '../interface/App.sol';
import '../interface/Constants.sol';

contract HelloWorld is App {
  function main(Kernel kernel, uint[] calldata, bytes calldata) external returns (uint) {
    uint fd = kernel.open('hello_world.txt', Constants.O_WRONLY() | Constants.O_CREAT());
    kernel.write(fd, 'Hello', 'World!');
    kernel.close(fd);
  }
}
