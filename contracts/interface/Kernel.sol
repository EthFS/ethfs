pragma solidity >= 0.5.8;

import './FileSystem.sol';

interface Kernel {
  function result() external view returns (bytes32);
  function open(bytes calldata path, uint flags) external returns (uint);
  function readkey(uint fd, uint index) external view returns (bytes memory);
  function readkeyPath(bytes calldata path, uint index) external view returns (bytes memory);
  function read(uint fd, bytes calldata key) external view returns (bytes memory);
  function readPath(bytes calldata path, bytes calldata key) external view returns (bytes memory);
  function write(uint fd, bytes calldata key, bytes calldata value) external;
  function clear(uint fd, bytes calldata key) external;
  function close(uint fd) external;
  function link(bytes calldata source, bytes calldata target) external;
  function unlink(bytes calldata path) external;
  function move(bytes calldata source, bytes calldata target) external;
  function install(address source, bytes calldata target) external;
  function getcwd() external view returns (bytes memory);
  function chdir(bytes calldata path) external;
  function mkdir(bytes calldata path) external;
  function rmdir(bytes calldata path) external;
  function stat(bytes calldata path) external view returns (FileSystem.FileType fileType, uint permissions, uint ino, address device, uint links, address owner, uint entries, uint lastModified);
  function fstat(uint fd) external view returns (FileSystem.FileType fileType, uint permissions, uint ino, address device, uint links, address owner, uint entries, uint lastModified);
  function exec(bytes calldata path, uint[] calldata argi, bytes calldata args) external returns (uint);
}
