pragma solidity >= 0.5.8;

import '../interface/Kernel.sol';
import '../interface/FileSystem.sol';
import '../interface/App.sol';

contract KernelImpl is Kernel {
  uint constant O_RDONLY  = 0x0000;
  uint constant O_WRONLY  = 0x0001;
  uint constant O_RDWR    = 0x0002;
  uint constant O_ACCMODE = 0x0003;

  uint constant O_CREAT = 0x0100;
  uint constant O_EXCL  = 0x0200;

  uint constant O_DIRECTORY = 0x00200000;

  struct FileDescriptor {
    uint ino;
    uint flags;
  }

  struct UserArea {
    bytes32 result;
    uint curdir;  // ino
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

  function open(bytes calldata path, uint flags) external returns (uint fd) {
    UserArea storage u = m_userArea[msg.sender];
    uint ino = m_fileSystem.open(path, u.curdir, flags);
    fd = u.fildes.length;
    u.fildes.push(FileDescriptor({
      ino: ino,
      flags: flags & O_ACCMODE
    }));
    u.result = bytes32(fd);
  }

  function read(uint fd, bytes32 key) external view returns (bytes32) {
    UserArea storage u = m_userArea[msg.sender];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_RDONLY || fildes.flags == O_RDWR, 'EBADF');
    return m_fileSystem.read(fildes.ino, key);
  }

  function readPath(bytes calldata path, bytes32 key) external view returns (bytes32) {
    UserArea storage u = m_userArea[msg.sender];
    uint ino = m_fileSystem.openOnly(path, u.curdir, 0);
    return m_fileSystem.read(ino, key);
  }

  function write(uint fd, bytes32 key, bytes32 data) external {
    UserArea storage u = m_userArea[msg.sender];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_WRONLY || fildes.flags == O_RDWR, 'EBADF');
    m_fileSystem.write(fildes.ino, key, data);
  }

  function clear(uint fd, bytes32 key) external {
    UserArea storage u = m_userArea[msg.sender];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_WRONLY || fildes.flags == O_RDWR, 'EBADF');
    m_fileSystem.clear(fildes.ino, key);
  }

  function close(uint fd) external {
    UserArea storage u = m_userArea[msg.sender];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    delete u.fildes[fd];
  }

  function link(bytes calldata source, bytes calldata target) external {
    UserArea storage u = m_userArea[msg.sender];
    m_fileSystem.link(source, target, u.curdir);
  }

  function unlink(bytes calldata path) external {
    UserArea storage u = m_userArea[msg.sender];
    m_fileSystem.unlink(path, u.curdir);
  }

  function move(bytes calldata source, bytes calldata target) external {
    UserArea storage u = m_userArea[msg.sender];
    m_fileSystem.move(source, target, u.curdir);
  }

  function install(address source, bytes calldata target) external {
    UserArea storage u = m_userArea[msg.sender];
    m_fileSystem.install(source, target, u.curdir);
  }

  function chdir(bytes calldata path) external {
    UserArea storage u = m_userArea[msg.sender];
    uint ino = m_fileSystem.openOnly(path, u.curdir, O_DIRECTORY);
    u.curdir = ino;
  }

  function mkdir(bytes calldata path) external {
    UserArea storage u = m_userArea[msg.sender];
    return m_fileSystem.mkdir(path, u.curdir);
  }

  function rmdir(bytes calldata path) external {
    UserArea storage u = m_userArea[msg.sender];
    return m_fileSystem.rmdir(path, u.curdir);
  }

  function list(bytes calldata path) external view returns (bytes32[] memory) {
    UserArea storage u = m_userArea[msg.sender];
    uint ino = m_fileSystem.openOnly(path, u.curdir, 0);
    return m_fileSystem.list(ino);
  }

  function exec(bytes calldata path, uint[] calldata argi, bytes calldata args) external returns (uint ret) {
    UserArea storage u = m_userArea[msg.sender];
    address app = m_fileSystem.readContract(path, u.curdir);
    m_userArea[app].curdir = u.curdir;
    ret = App(app).main(this, argi, args);
    u.result = bytes32(ret);
  }
}
