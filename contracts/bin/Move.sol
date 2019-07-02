pragma solidity >= 0.5.8;

import '../interface/App.sol';

contract Move is App {
  constructor(Kernel kernel) public {
    install(kernel);
  }

  function install(Kernel kernel) public {
    kernel.install(address(this), '/bin/mv');
  }

  function main(Kernel kernel, uint[] calldata argi, bytes calldata args) external returns (uint) {
    require(argi.length >= 2, 'EINVAL');
    uint index = argi[argi.length-2];
    bytes memory target = new bytes(argi[argi.length-1] - index);
    for (uint i; i < target.length; i++) {
      target[i] = args[index + i];
    }
    if (argi.length > 2) {
      (FileSystem.FileType fileType,,,,,,,) = kernel.stat(target);
      require(fileType == FileSystem.FileType.Directory, 'ENOTDIR');
    }
    for (uint i; i < argi.length-1; i++) {
      index = i > 0 ? argi[i-1] : 0;
      bytes memory source = new bytes(argi[i] - index);
      for (uint j; j < source.length; j++) {
        source[j] = args[index + j];
      }
      kernel.move(source, target);
    }
  }
}
