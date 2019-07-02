pragma solidity >= 0.5.8;

import '../interface/App.sol';

contract DeleteTree is App {
  constructor(Kernel kernel) public {
    install(kernel);
  }

  function install(Kernel kernel) public {
    kernel.install(address(this), '/bin/deltree');
  }

  function main(Kernel kernel, uint[] calldata argi, bytes calldata args) external returns (uint) {
    require(argi.length > 0, 'EINVAL');
    for (uint i; i < argi.length; i++) {
      uint index = i > 0 ? argi[i-1] : 0;
      bytes memory path = new bytes(argi[i] - index);
      for (uint j; j < path.length; j++) {
        path[j] = args[index + j];
      }
      deltree(kernel, path);
    }
  }

  function deltree(Kernel kernel, bytes memory path) private {
    (FileSystem.FileType fileType,,,,,, uint entries,) = kernel.stat(path);
    if (fileType != FileSystem.FileType.Directory) {
      kernel.unlink(path);
      return;
    }
    uint fd = kernel.open(path, 0);
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
