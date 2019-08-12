pragma solidity >= 0.5.8;

interface FileSystem {
  enum FileType { None, Regular, Directory, Symlink }

  function mount() external;
  function unmount() external;
  function dirInodeToPath(uint ino) external view returns (bytes memory);
  function open(bytes calldata path, uint curdir, uint flags) external returns (uint);
  function openOnly(bytes calldata path, uint curdir, uint flags) external view returns (uint);
  function close(uint ino) external;
  function readkey(uint ino, uint index) external view returns (bytes memory);
  function read(uint ino, bytes calldata key) external view returns (bytes memory);
  function write(uint ino, bytes calldata key, bytes calldata value) external;
  function truncate(uint ino, bytes calldata key, uint len) external;
  function clear(uint ino, bytes calldata key) external;
  function link(bytes calldata source, bytes calldata target, uint curdir) external;
  function unlink(bytes calldata path, uint curdir) external;
  function symlink(bytes calldata source, bytes calldata target, uint curdir) external;
  function readlink(bytes calldata path, uint curdir) external view returns (bytes memory);
  function move(bytes calldata source, bytes calldata target, uint curdir) external;
  function copy(bytes calldata source, bytes calldata target, uint curdir) external;
  function mkdir(bytes calldata path, uint curdir) external;
  function rmdir(bytes calldata path, uint curdir) external;
  function stat(bytes calldata path, uint curdir) external view returns (FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint size, uint lastModified);
  function fstat(uint ino) external view returns (FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint size, uint lastModified);
}
