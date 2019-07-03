pragma solidity >= 0.5.8;

import './Lib0.sol';

library FileSystemLib2 {
  using FileSystemLib for FileSystemLib.Disk;

  modifier onlyOwner(FileSystemLib.Disk storage self) {
    require(msg.sender == self.owner, 'EPERM');
    _;
  }

  function move(FileSystemLib.Disk storage self, bytes calldata source, bytes calldata target, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = self.pathToInode(source, curdir, false);
    require(ino > 0, 'ENOENT');
    bool sourceIsDir = self.inode[ino].fileType == FileSystem.FileType.Directory;
    (uint ino2, uint dirIno2, bytes memory key2) = self.pathToInode(target, curdir, true);
    if (ino == ino2) return;
    if (ino2 > 0) {
      FileSystemLib.Inode storage inode = self.inode[ino2];
      if (inode.fileType == FileSystem.FileType.Directory) {
        if (ino2 == dirIno) return;
        dirIno2 = ino2;
        key2 = key;
      } else {
        require(!sourceIsDir, 'ENOTDIR');
        self.removeFromInode(dirIno2, key2);
        if (--inode.links == 0) self.freeInode(ino2);
      }
    } else if (!sourceIsDir) {
      require(target[target.length-1] != '/', 'ENOENT');
    }
    if (sourceIsDir) {
      ino2 = dirIno2;
      while (true) {
        require(ino2 != ino, 'EINVAL');
        if (ino2 == 1) break;
        ino2 = self.inodeData[self.inode[ino2].data['..']].value;
      }
      self.writeToInode(ino, '..', dirIno2);
    }
    self.removeFromInode(dirIno, key);
    self.writeToInode(dirIno2, key2, ino);
  }

  function copy(FileSystemLib.Disk storage self, bytes calldata sourcePath, bytes calldata targetPath, uint curdir) external onlyOwner(self) {
    FileSystemLib.ResolvedPath memory source = self.pathToInode2(sourcePath, curdir, false);
    require(source.ino > 0, 'ENOENT');
    FileSystemLib.Inode storage inode = self.inode[source.ino];
    bool sourceIsDir = inode.fileType == FileSystem.FileType.Directory;
    FileSystemLib.ResolvedPath memory target = self.pathToInode2(targetPath, curdir, true);
    if (source.ino == target.ino) return;
    uint newIno;
    if (target.ino > 0) {
      FileSystemLib.Inode storage inode2 = self.inode[target.ino];
      if (inode2.fileType == FileSystem.FileType.Directory) {
        if (target.ino == source.dirIno) return;
        target.dirIno = target.ino;
        target.key = source.key;
      } else {
        require(!sourceIsDir, 'ENOTDIR');
        if (--inode2.links == 0) newIno = target.ino;
      }
    } else if (!sourceIsDir) {
      require(targetPath[targetPath.length-1] != '/', 'ENOENT');
    }
    if (sourceIsDir) {
      uint ino = target.dirIno;
      while (true) {
        require(ino != source.ino, 'EINVAL');
        if (ino == 1) break;
        ino = self.inodeData[self.inode[ino].data['..']].value;
      }
    }
    if (newIno == 0) {
      newIno = self.allocInode();
      self.writeToInode(target.dirIno, target.key, newIno);
    }
    copyInode(self, inode, newIno, target.dirIno);
  }

  function copyInode(FileSystemLib.Disk storage self, FileSystemLib.Inode storage inode, uint ino, uint dirIno) private {
    bool sourceIsDir = inode.fileType == FileSystem.FileType.Directory;
    FileSystemLib.Inode storage inode2 = self.inode[ino];
    inode2.owner = inode.owner;
    inode2.fileType = inode.fileType;
    inode2.permissions = inode.permissions;
    uint i;
    if (sourceIsDir) {
      i = 2;
      self.writeToInode(ino, '.', ino);
      self.writeToInode(ino, '..', dirIno);
    } else {
      inode2.links = 1;
      while (i < inode2.keys.length) {
        bytes storage key = inode2.keys[i++];
        self.freeInoData.push(inode2.data[key]);
        delete inode2.data[key];
      }
      i = 0;
    }
    inode2.lastModified = inode.lastModified;
    inode2.keys.length = inode.keys.length;
    for (; i < inode.keys.length; i++) {
      bytes storage key = inode.keys[i];
      inode2.keys[i] = key;
      inode2.data[key] = self.allocInodeData();
      FileSystemLib.InodeData storage data = self.inodeData[inode.data[key]];
      FileSystemLib.InodeData storage data2 = self.inodeData[inode2.data[key]];
      data2.index = data.index;
      if (sourceIsDir) {
        data2.value = self.allocInode();
        copyInode(self, self.inode[data.value], data2.value, ino);
      } else {
        data2.extent = data.extent;
      }
    }
  }
}
