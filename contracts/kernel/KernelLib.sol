pragma solidity >= 0.5.8;

import '../interface/FileSystem.sol';
import '../interface/App.sol';

library KernelLib {
  uint constant O_RDONLY  = 0x0000;
  uint constant O_WRONLY  = 0x0001;
  uint constant O_RDWR    = 0x0002;
  uint constant O_ACCMODE = 0x0003;

  uint constant O_CREAT = 0x0100;
  uint constant O_EXCL  = 0x0200;

  uint constant O_DIRECTORY = 0x00200000;

  struct KernelArea {
    address rootUser;
    FileSystem fileSystem;
    mapping(address => UserArea) userArea;
  }

  struct UserArea {
    uint result;
    uint curdir;  // ino
    FileDescriptor[] fildes;
  }

  struct FileDescriptor {
    uint ino;
    uint flags;
  }

  function init(KernelArea storage self, FileSystem fileSystem) external {
    self.rootUser = tx.origin;
    self.fileSystem = fileSystem;
    self.fileSystem.mount();
  }

  function result(KernelArea storage self) external view returns (uint) {
    return self.userArea[tx.origin].result;
  }

  function open(KernelArea storage self, bytes calldata path, uint flags) external returns (uint fd) {
    UserArea storage u = self.userArea[tx.origin];
    uint ino = self.fileSystem.open(path, u.curdir, flags);
    fd = u.fildes.length;
    u.fildes.push(FileDescriptor({
      ino: ino,
      flags: flags & O_ACCMODE
    }));
    u.result = fd;
  }

  function readkey(KernelArea storage self, uint fd, uint index) external view returns (bytes memory) {
    UserArea storage u = self.userArea[tx.origin];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_RDONLY || fildes.flags == O_RDWR, 'EBADF');
    return self.fileSystem.readkey(fildes.ino, index);
  }

  function readkeyPath(KernelArea storage self, bytes calldata path, uint index) external view returns (bytes memory) {
    UserArea storage u = self.userArea[tx.origin];
    uint ino = self.fileSystem.openOnly(path, u.curdir, 0);
    return self.fileSystem.readkey(ino, index);
  }

  function read(KernelArea storage self, uint fd, bytes calldata key) external view returns (bytes memory) {
    UserArea storage u = self.userArea[tx.origin];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_RDONLY || fildes.flags == O_RDWR, 'EBADF');
    return self.fileSystem.read(fildes.ino, key);
  }

  function readPath(KernelArea storage self, bytes calldata path, bytes calldata key) external view returns (bytes memory) {
    UserArea storage u = self.userArea[tx.origin];
    uint ino = self.fileSystem.openOnly(path, u.curdir, 0);
    return self.fileSystem.read(ino, key);
  }

  function write(KernelArea storage self, uint fd, bytes calldata key, bytes calldata value) external {
    UserArea storage u = self.userArea[tx.origin];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_WRONLY || fildes.flags == O_RDWR, 'EBADF');
    self.fileSystem.write(fildes.ino, key, value);
  }

  function clear(KernelArea storage self, uint fd, bytes calldata key) external {
    UserArea storage u = self.userArea[tx.origin];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_WRONLY || fildes.flags == O_RDWR, 'EBADF');
    self.fileSystem.clear(fildes.ino, key);
  }

  function close(KernelArea storage self, uint fd) external {
    UserArea storage u = self.userArea[tx.origin];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    delete u.fildes[fd];
  }

  function link(KernelArea storage self, bytes calldata source, bytes calldata target) external {
    UserArea storage u = self.userArea[tx.origin];
    self.fileSystem.link(source, target, u.curdir);
  }

  function unlink(KernelArea storage self, bytes calldata path) external {
    UserArea storage u = self.userArea[tx.origin];
    self.fileSystem.unlink(path, u.curdir);
  }

  function move(KernelArea storage self, bytes calldata source, bytes calldata target) external {
    UserArea storage u = self.userArea[tx.origin];
    self.fileSystem.move(source, target, u.curdir);
  }

  function copy(KernelArea storage self, bytes calldata source, bytes calldata target) external {
    UserArea storage u = self.userArea[tx.origin];
    self.fileSystem.copy(source, target, u.curdir);
  }

  function install(KernelArea storage self, address source, bytes calldata target) external {
    UserArea storage u = self.userArea[tx.origin];
    self.fileSystem.install(source, target, u.curdir);
  }

  function getcwd(KernelArea storage self) external view returns (bytes memory) {
    UserArea storage u = self.userArea[tx.origin];
    uint ino = u.curdir;
    if (ino == 0) ino = 1;
    return self.fileSystem.dirInodeToPath(ino);
  }

  function chdir(KernelArea storage self, bytes calldata path) external {
    UserArea storage u = self.userArea[tx.origin];
    uint ino = self.fileSystem.open(path, u.curdir, O_DIRECTORY);
    if (u.curdir > 0) self.fileSystem.close(u.curdir);
    u.curdir = ino;
  }

  function mkdir(KernelArea storage self, bytes calldata path) external {
    UserArea storage u = self.userArea[tx.origin];
    return self.fileSystem.mkdir(path, u.curdir);
  }

  function rmdir(KernelArea storage self, bytes calldata path) external {
    UserArea storage u = self.userArea[tx.origin];
    return self.fileSystem.rmdir(path, u.curdir);
  }

  function stat(KernelArea storage self, bytes calldata path) external view returns (FileSystem.FileType fileType, uint permissions, uint ino, address device, uint links, address owner, uint entries, uint lastModified) {
    UserArea storage u = self.userArea[tx.origin];
    return self.fileSystem.stat(path, u.curdir);
  }

  function fstat(KernelArea storage self, uint fd) external view returns (FileSystem.FileType fileType, uint permissions, uint ino, address device, uint links, address owner, uint entries, uint lastModified) {
    UserArea storage u = self.userArea[tx.origin];
    FileDescriptor storage fildes = u.fildes[fd];
    require(fildes.ino > 0, 'EBADF');
    require(fildes.flags == O_RDONLY || fildes.flags == O_RDWR, 'EBADF');
    return self.fileSystem.fstat(fildes.ino);
  }

  function exec(KernelArea storage self, bytes calldata path, uint[] calldata argi, bytes calldata args) external returns (uint ret) {
    UserArea storage u = self.userArea[tx.origin];
    address app = self.fileSystem.readContract(path, u.curdir);
    ret = App(app).main(Kernel(address(this)), argi, args);
    u.result = ret;
  }
}
