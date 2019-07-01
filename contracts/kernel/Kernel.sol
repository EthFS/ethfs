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

  function readkey(uint fd, uint index) external view returns (bytes memory) {
    UserArea storage u = m_userArea[msg.sender];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_RDONLY || fildes.flags == O_RDWR, 'EBADF');
    return m_fileSystem.readkey(fildes.ino, index);
  }

  function readkeyPath(bytes calldata path, uint index) external view returns (bytes memory) {
    UserArea storage u = m_userArea[msg.sender];
    uint ino = m_fileSystem.openOnly(path, u.curdir, 0);
    return m_fileSystem.readkey(ino, index);
  }

  function read(uint fd, bytes calldata key) external view returns (bytes memory) {
    UserArea storage u = m_userArea[msg.sender];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_RDONLY || fildes.flags == O_RDWR, 'EBADF');
    return m_fileSystem.read(fildes.ino, key);
  }

  function readPath(bytes calldata path, bytes calldata key) external view returns (bytes memory) {
    UserArea storage u = m_userArea[msg.sender];
    uint ino = m_fileSystem.openOnly(path, u.curdir, 0);
    return m_fileSystem.read(ino, key);
  }

  function write(uint fd, bytes calldata key, bytes calldata value) external {
    UserArea storage u = m_userArea[msg.sender];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_WRONLY || fildes.flags == O_RDWR, 'EBADF');
    m_fileSystem.write(fildes.ino, key, value);
  }

  function clear(uint fd, bytes calldata key) external {
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

  function copy(bytes calldata source, bytes calldata target) external {
    UserArea storage u = m_userArea[msg.sender];
    m_fileSystem.copy(source, target, u.curdir);
  }

  function install(address source, bytes calldata target) external {
    UserArea storage u = m_userArea[msg.sender];
    m_fileSystem.install(source, target, u.curdir);
  }

  function getcwd() external view returns (bytes memory) {
    UserArea storage u = m_userArea[msg.sender];
    uint ino = u.curdir;
    if (ino == 0) ino = 1;
    return m_fileSystem.dirInodeToPath(ino);
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

  function stat(bytes calldata path) external view returns (FileSystem.FileType fileType, uint permissions, uint ino, address device, uint links, address owner, uint entries, uint lastModified) {
    UserArea storage u = m_userArea[msg.sender];
    return m_fileSystem.stat(path, u.curdir);
  }

  function fstat(uint fd) external view returns (FileSystem.FileType fileType, uint permissions, uint ino, address device, uint links, address owner, uint entries, uint lastModified) {
    UserArea storage u = m_userArea[msg.sender];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_RDONLY || fildes.flags == O_RDWR, 'EBADF');
    return m_fileSystem.fstat(fildes.ino);
  }

  function exec(bytes calldata path, uint[] calldata argi, bytes calldata args) external returns (uint ret) {
    UserArea storage u = m_userArea[msg.sender];
    address app = m_fileSystem.readContract(path, u.curdir);
    m_userArea[app].curdir = u.curdir;
    ret = App(app).main(this, argi, args);
    u.result = bytes32(ret);
  }
}
