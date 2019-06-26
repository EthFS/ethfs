pragma solidity >= 0.5.8;

interface FileSystem {
  function mount() external;
  function unmount() external;
  function open(bytes32[] calldata path, uint curdir, uint flags) external returns (uint);
  function openOnly(bytes32[] calldata path, uint curdir, uint flags) external view returns (uint);
  function read(uint inode, bytes32 key) external view returns (bytes32);
  function write(uint inode, bytes32 key, bytes32 data) external;
  function clear(uint inode, bytes32 key) external;
  function link(bytes32[] calldata source, bytes32[] calldata target, uint curdir) external;
  function unlink(bytes32[] calldata path, uint curdir) external;
  function linkContract(address source, bytes32[] calldata target, uint curdir) external;
  function mkdir(bytes32[] calldata path, uint curdir) external;
  function rmdir(bytes32[] calldata path, uint curdir) external;
  function list(uint inode) external view returns (bytes32[] memory);
  function readContract(bytes32[] calldata path, uint curdir) external view returns (address);
}
