pragma solidity >= 0.5.8;

import './Lib0.sol';

library FileSystemLib1 {
  using FileSystemLib for FileSystemLib.Disk;

  modifier onlyOwner(FileSystemLib.Disk storage self) {
    require(msg.sender == self.owner, 'EPERM');
    _;
  }

  function link(FileSystemLib.Disk storage self, bytes calldata source, bytes calldata target, uint curdir) external onlyOwner(self) {
    (uint ino,, bytes memory key) = self.pathToInode(source, curdir, false);
    require(ino > 0, 'ENOENT');
    FileSystemLib.Inode storage inode = self.inode[ino];
    require(inode.fileType != FileSystem.FileType.Directory, 'EISDIR');
    (uint ino2, uint dirIno, bytes memory key2) = self.pathToInode(target, curdir, false);
    if (ino2 > 0) {
      require(self.inode[ino2].fileType == FileSystem.FileType.Directory, 'EEXIST');
      dirIno = ino2;
    } else {
      key = key2;
    }
    require(self.inode[dirIno].data[key] == 0, 'EEXIST');
    self.writeToInode(dirIno, key, ino);
    inode.links++;
  }

  function unlink(FileSystemLib.Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = self.pathToInode(path, curdir, false);
    require(ino > 0, 'ENOENT');
    FileSystemLib.Inode storage inode = self.inode[ino];
    require(inode.fileType != FileSystem.FileType.Directory, 'EISDIR');
    self.removeFromInode(dirIno, key);
    if (--inode.links == 0) self.freeInode(ino);
  }

  function install(FileSystemLib.Disk storage self, address source, bytes calldata target, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = self.pathToInode(target, curdir, false);
    if (ino > 0) {
      FileSystemLib.Inode storage inode = self.inode[ino];
      require(inode.fileType != FileSystem.FileType.Directory, 'EISDIR');
      if (--inode.links == 0) self.freeInode(ino);
    }
    ino = self.allocInode();
    FileSystemLib.Inode storage inode = self.inode[ino];
    inode.owner = source;
    inode.fileType = FileSystem.FileType.Contract;
    inode.lastModified = now;
    inode.links = 1;
    self.writeToInode(dirIno, key, ino);
  }

  function readContract(FileSystemLib.Disk storage self, bytes calldata path, uint curdir) external view onlyOwner(self) returns (address) {
    (uint ino,,) = self.pathToInode(path, curdir, false);
    require(ino > 0, 'ENOENT');
    FileSystemLib.Inode storage inode = self.inode[ino];
    require(inode.fileType != FileSystem.FileType.Directory, 'EISDIR');
    require(inode.fileType == FileSystem.FileType.Contract, 'ENOEXEC');
    return inode.owner;
  }

  function mkdir(FileSystemLib.Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = self.pathToInode(path, curdir, true);
    require(ino == 0, 'EEXIST');
    ino = self.allocInode();
    FileSystemLib.Inode storage inode = self.inode[ino];
    inode.owner = tx.origin;
    inode.fileType = FileSystem.FileType.Directory;
    inode.refCnt = 1;
    self.writeToInode(dirIno, key, ino);
    self.writeToInode(ino, '.', ino);
    self.writeToInode(ino, '..', dirIno);
  }

  function rmdir(FileSystemLib.Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = self.pathToInode(path, curdir, false);
    require(ino > 0, 'ENOENT');
    require(ino != 1 && ino != curdir, 'EBUSY');
    FileSystemLib.Inode storage inode = self.inode[ino];
    require(inode.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
    require(inode.keys.length == 2, 'ENOTEMPTY');
    self.removeFromInode(dirIno, key);
    if (--inode.refCnt == 0) self.freeInode(ino);
  }
}
