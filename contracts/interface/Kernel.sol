pragma solidity >= 0.5.8;

interface Kernel {
  function result() external view returns (bytes32);
  function open(bytes calldata path, uint flags) external returns (uint);
  function read(uint fd, bytes32 key) external view returns (bytes32);
  function readPath(bytes calldata path, bytes32 key) external view returns (bytes32);
  function write(uint fd, bytes32 key, bytes32 data) external;
  function clear(uint fd, bytes32 key) external;
  function close(uint fd) external;
  function link(bytes calldata source, bytes calldata target) external;
  function unlink(bytes calldata path) external;
  function move(bytes calldata source, bytes calldata target) external;
  function install(address source, bytes calldata target) external;
  function chdir(bytes calldata path) external;
  function mkdir(bytes calldata path) external;
  function rmdir(bytes calldata path) external;
  function list(uint fd) external view returns (bytes32[] memory);
  function listPath(bytes calldata path) external view returns (bytes32[] memory);
  function exec(bytes calldata path, uint[] calldata argi, bytes calldata args) external returns (uint);
}
