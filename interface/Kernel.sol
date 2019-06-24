pragma solidity >= 0.5.8;

interface Kernel {
  function result() external view returns (bytes32);
  function open(bytes32[] calldata path, uint flags) external returns (uint);
  function read(uint fd, bytes32 key) external view returns (bytes32);
  function read2(bytes32[] calldata path, bytes32 key) external view returns (bytes32);
  function write(uint fd, bytes32 key, bytes32 data) external;
  function close(uint fd) external;
  function link(bytes32[] calldata source, bytes32[] calldata target) external;
  function unlink(bytes32[] calldata path) external;
  function linkContract(address source, bytes32[] calldata target) external;
  function list(bytes32[] calldata path) external view returns (bytes32[] memory);
  function exec(bytes32[] calldata path, bytes32[] calldata args) external returns (uint);
}
