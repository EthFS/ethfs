pragma solidity >= 0.5.8;

import '../interface/App.sol';

contract Copy is App {
  constructor(Kernel kernel) public {
    install(kernel);
  }

  function install(Kernel kernel) public {
    kernel.install(address(this), '/bin/cp');
  }

  function main(Kernel kernel, uint[] calldata argi, bytes calldata args) external returns (uint) {
    require(argi.length >= 2, 'EINVAL');
    bytes memory target = new bytes(args.length - argi[argi.length-1]);
    for (uint i = 0; i < target.length; i++) {
      target[i] = args[argi[argi.length-1] + i];
    }
    for (uint i = 0; i < argi.length-1; i++) {
      bytes memory source = new bytes(argi[i+1] - argi[i]);
      for (uint j = 0; j < source.length; j++) {
        source[j] = args[argi[i] + j];
      }
      uint fd = kernel.open(source, 0);
      uint fd2 = kernel.open(target, 0x0101);
      (,,,,,, uint entries,) = kernel.fstat(fd);
      for (uint j; j < entries; j++) {
        bytes memory key = kernel.readkey(fd, j);
        bytes memory value = kernel.read(fd, key);
        kernel.write(fd2, key, value);
      }
      kernel.close(fd);
      kernel.close(fd2);
    }
  }
}
