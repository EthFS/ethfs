pragma solidity >= 0.5.9;

interface FileSystem {
  function mount() external;
  function unmount() external;
  function open(address sender, bytes32[] calldata path, uint flags) external returns(uint);
  function read(uint inode, bytes32 key) external view returns(bytes32);
  function write(uint inode, bytes32 key, bytes32 data) external;
  function link(bytes32[] calldata source, bytes32[] calldata target) external;
  function unlink(bytes32[] calldata path) external;
  function linkContract(address source, bytes32[] calldata target) external;
}
