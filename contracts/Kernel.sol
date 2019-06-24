pragma solidity >= 0.5.8;

import "../interface/Kernel.sol";
import "../interface/FileSystem.sol";
import "../interface/App.sol";

contract KernelImpl is Kernel {
  uint constant O_RDONLY  = 0x0000;
  uint constant O_WRONLY  = 0x0001;
  uint constant O_RDWR    = 0x0002;
  uint constant O_ACCMODE = 0x0003;

  uint constant O_CREAT = 0x0200;
  uint constant O_EXCL  = 0x0800;

  struct FileDescriptor {
    uint inode;
    uint flags;
  }

  address m_rootUser;
  FileSystem m_fileSystem;
  mapping(address => FileDescriptor[]) m_fileDescriptors;
  mapping(address => bytes32) m_result;

  constructor(FileSystem fileSystem) public {
    m_rootUser = tx.origin;
    m_fileSystem = fileSystem;
    m_fileSystem.mount();
  }

  function result() external view returns (bytes32) {
    return m_result[msg.sender];
  }

  function open(bytes32[] calldata path, uint flags) external returns (uint) {
    uint inode = m_fileSystem.open(tx.origin, path, flags);
    uint fd = m_fileDescriptors[msg.sender].length;
    m_fileDescriptors[msg.sender].push(FileDescriptor({
      inode: inode,
      flags: flags & O_ACCMODE
    }));
    m_result[msg.sender] = bytes32(fd);
    return fd;
  }

  function read(uint fd, bytes32 key) external view returns (bytes32) {
    uint inode = m_fileDescriptors[msg.sender][fd].inode;
    require(inode > 0, "EBADF");
    uint flags = m_fileDescriptors[msg.sender][fd].flags;
    require(flags == O_RDONLY || flags == O_RDWR, "EBADF");
    return m_fileSystem.read(inode, key);
  }

  function read2(bytes32[] calldata path, bytes32 key) external view returns (bytes32) {
    uint inode = m_fileSystem.openOnly(tx.origin, path, 0);
    return m_fileSystem.read(inode, key);
  }

  function write(uint fd, bytes32 key, bytes32 data) external {
    require(m_fileDescriptors[msg.sender][fd].inode > 0, "EBADF");
    uint flags = m_fileDescriptors[msg.sender][fd].flags;
    require(flags == O_WRONLY || flags == O_RDWR, "EBADF");
    uint inode = m_fileDescriptors[msg.sender][fd].inode;
    m_fileSystem.write(inode, key, data);
  }

  function close(uint fd) external {
    require(m_fileDescriptors[msg.sender][fd].inode > 0, "EBADF");
    delete m_fileDescriptors[msg.sender][fd];
  }

  function link(bytes32[] calldata source, bytes32[] calldata target) external {
    m_fileSystem.link(source, target);
  }

  function unlink(bytes32[] calldata path) external {
    m_fileSystem.unlink(path);
  }

  function linkContract(address source, bytes32[] calldata target) external {
    m_fileSystem.linkContract(source, target);
  }

  function list(bytes32[] calldata path) external view returns (bytes32[] memory) {
    uint inode = m_fileSystem.openOnly(tx.origin, path, 0);
    return m_fileSystem.list(inode);
  }

  function exec(bytes32[] calldata path, bytes32[] calldata args) external returns (uint) {
    App app = App(m_fileSystem.readContract(path));
    app.main(this, args);
  }
}
