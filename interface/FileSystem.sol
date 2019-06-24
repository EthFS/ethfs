pragma solidity >= 0.5.8;

interface FileSystem {
  function mount() external;
  function unmount() external;
  function open(address sender, bytes32[] calldata path, uint flags) external returns (uint);
  function openOnly(address sender, bytes32[] calldata path, uint flags) external view returns (uint);
  function read(uint inode, bytes32 key) external view returns (bytes32);
  function write(uint inode, bytes32 key, bytes32 data) external;
  function link(bytes32[] calldata source, bytes32[] calldata target) external;
  function unlink(bytes32[] calldata path) external;
  function linkContract(address source, bytes32[] calldata target) external;
  function list(uint inode) external view returns (bytes32[] memory);
  function readContract(bytes32[] calldata path) external view returns (address);
}
