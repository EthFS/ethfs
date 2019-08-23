pragma solidity >= 0.5.8;

import './FileSystem.sol';

interface Kernel {
  function result() external view returns (uint);
  function open(bytes calldata path, uint flags) external returns (uint);
  function readkey(uint fd, uint index) external view returns (bytes memory);
  function readkeyPath(bytes calldata path, uint index) external view returns (bytes memory);
  function read(uint fd, bytes calldata key) external view returns (bytes memory);
  function readPath(bytes calldata path, bytes calldata key) external view returns (bytes memory);
  function write(uint fd, bytes calldata key, bytes calldata value) external;
  function truncate(uint fd, bytes calldata key, uint len) external;
  function clear(uint fd, bytes calldata key) external;
  function close(uint fd) external;
  function link(bytes calldata source, bytes calldata target) external;
  function unlink(bytes calldata path) external;
  function symlink(bytes calldata source, bytes calldata target) external;
  function readlink(bytes calldata path) external view returns (bytes memory);
  function move(bytes calldata source, bytes calldata target) external;
  function copy(bytes calldata source, bytes calldata target) external;
  function chown(bytes calldata path, address owner, address group) external;
  function chmod(bytes calldata path, uint16 mode) external;
  function getcwd() external view returns (bytes memory);
  function chdir(bytes calldata path) external;
  function mkdir(bytes calldata path) external;
  function rmdir(bytes calldata path) external;
  function stat(bytes calldata path) external view returns (FileSystem.FileType fileType, uint16 mode, uint ino, uint links, address owner, address group, uint entries, uint size, uint lastModified);
  function fstat(uint fd) external view returns (FileSystem.FileType fileType, uint16 mode, uint ino, uint links, address owner, address group, uint entries, uint size, uint lastModified);
}
