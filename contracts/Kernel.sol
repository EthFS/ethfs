pragma solidity >= 0.5.8;

import "../interface/Kernel.sol";
import "../interface/FileSystem.sol";
import "../interface/App.sol";

contract KernelImpl is Kernel {
  uint constant O_RDONLY  = 0x0000;
  uint constant O_WRONLY  = 0x0001;
  uint constant O_RDWR    = 0x0002;
  uint constant O_ACCMODE = 0x0003;

  uint constant O_CREAT = 0x0100;
  uint constant O_EXCL  = 0x0200;

  uint constant O_DIRECTORY = 0x00200000;

  struct FileDescriptor {
    uint inode;
    uint flags;
  }

  struct UserArea {
    bytes32 result;
    uint curdir;  // inode
    FileDescriptor[] fildes;
  }

  address m_rootUser;
  FileSystem m_fileSystem;
  mapping(address => UserArea) m_userArea;

  constructor(FileSystem fileSystem) public {
    m_rootUser = tx.origin;
    m_fileSystem = fileSystem;
    m_fileSystem.mount();
  }

  function result() external view returns (bytes32) {
    return m_userArea[msg.sender].result;
  }

  function open(bytes32[] calldata path, uint flags) external returns (uint) {
    uint inode = m_fileSystem.open(path, m_userArea[msg.sender].curdir, flags);
    uint fd = m_userArea[msg.sender].fildes.length;
    m_userArea[msg.sender].fildes.push(FileDescriptor({
      inode: inode,
      flags: flags & O_ACCMODE
    }));
    m_userArea[msg.sender].result = bytes32(fd);
    return fd;
  }

  function read(uint fd, bytes32 key) external view returns (bytes32) {
    uint inode = m_userArea[msg.sender].fildes[fd].inode;
    require(inode > 0, "EBADF");
    uint flags = m_userArea[msg.sender].fildes[fd].flags;
    require(flags == O_RDONLY || flags == O_RDWR, "EBADF");
    return m_fileSystem.read(inode, key);
  }

  function read2(bytes32[] calldata path, bytes32 key) external view returns (bytes32) {
    uint inode = m_fileSystem.openOnly(path, m_userArea[msg.sender].curdir, 0);
    return m_fileSystem.read(inode, key);
  }

  function write(uint fd, bytes32 key, bytes32 data) external {
    require(m_userArea[msg.sender].fildes[fd].inode > 0, "EBADF");
    uint flags = m_userArea[msg.sender].fildes[fd].flags;
    require(flags == O_WRONLY || flags == O_RDWR, "EBADF");
    uint inode = m_userArea[msg.sender].fildes[fd].inode;
    m_fileSystem.write(inode, key, data);
  }

  function close(uint fd) external {
    require(m_userArea[msg.sender].fildes[fd].inode > 0, "EBADF");
    delete m_userArea[msg.sender].fildes[fd];
  }

  function link(bytes32[] calldata source, bytes32[] calldata target) external {
    m_fileSystem.link(source, target, m_userArea[msg.sender].curdir);
  }

  function unlink(bytes32[] calldata path) external {
    m_fileSystem.unlink(path, m_userArea[msg.sender].curdir);
  }

  function linkContract(address source, bytes32[] calldata target) external {
    m_fileSystem.linkContract(source, target, m_userArea[msg.sender].curdir);
  }

  function chdir(bytes32[] calldata path) external {
    uint inode = m_fileSystem.openOnly(path, m_userArea[msg.sender].curdir, O_DIRECTORY);
    m_userArea[msg.sender].curdir = inode;
  }

  function mkdir(bytes32[] calldata path) external {
    return m_fileSystem.mkdir(path, m_userArea[msg.sender].curdir);
  }

  function rmdir(bytes32[] calldata path) external {
    return m_fileSystem.rmdir(path, m_userArea[msg.sender].curdir);
  }

  function list(bytes32[] calldata path) external view returns (bytes32[] memory) {
    uint inode = m_fileSystem.openOnly(path, m_userArea[msg.sender].curdir, 0);
    return m_fileSystem.list(inode);
  }

  function exec(bytes32[] calldata path, bytes32[] calldata args) external returns (uint) {
    App app = App(m_fileSystem.readContract(path, m_userArea[msg.sender].curdir));
    app.main(this, args);
  }
}
