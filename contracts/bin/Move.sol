pragma solidity >= 0.5.8;

import '../interface/App.sol';

contract Move is App {
  function main(Kernel kernel, uint[] calldata argi, bytes calldata args) external returns (uint) {
    require(argi.length >= 2, 'EINVAL');
    bytes memory p = args;
    uint index = argi[argi.length-1];
    assembly { p := add(p, index) }
    (bytes memory target) = abi.decode(p, (bytes));
    if (argi.length > 2) {
      (FileSystem.FileType fileType,,,,,,,) = kernel.stat(target);
      require(fileType == FileSystem.FileType.Directory, 'ENOTDIR');
    }
    for (uint i; i < argi.length-1; i++) {
      p = args;
      index = argi[i];
      assembly { p := add(p, index) }
      (bytes memory source) = abi.decode(p, (bytes));
      kernel.move(source, target);
    }
  }
}
