pragma solidity >= 0.5.8;

import '../interface/App.sol';
import '../interface/Constants.sol';

contract DeleteTree is App {
  function main(Kernel kernel, uint[] calldata argi, bytes calldata args) external returns (uint) {
    require(argi.length > 0, 'EINVAL');
    for (uint i; i < argi.length; i++) {
      bytes memory p = args;
      uint index = argi[i];
      assembly { p := add(p, index) }
      (bytes memory path) = abi.decode(p, (bytes));
      deltree(kernel, path);
    }
  }

  function deltree(Kernel kernel, bytes memory path) private {
    (FileSystem.FileType fileType,,,,,, uint entries,,) = kernel.stat(path);
    if (fileType != FileSystem.FileType.Directory) {
      kernel.unlink(path);
      return;
    }
    uint fd = kernel.open(path, Constants.O_RDONLY());
    for (uint i = entries-1; i > 1; i--) {
      bytes memory key = kernel.readkey(fd, i);
      bytes memory path2 = new bytes(path.length + key.length + 1);
      uint k;
      for (uint j; j < path.length;) path2[k++] = path[j++];
      path2[k++] = '/';
      for (uint j; j < key.length;) path2[k++] = key[j++];
      deltree(kernel, path2);
    }
    kernel.close(fd);
    kernel.rmdir(path);
  }
}
