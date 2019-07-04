pragma solidity >= 0.5.8;

import './Lib0.sol';

library FileSystemLib2 {
  using FileSystemLib for FileSystemLib.Disk;

  modifier onlyOwner(FileSystemLib.Disk storage self) {
    require(msg.sender == self.owner, 'EPERM');
    _;
  }

  function move(FileSystemLib.Disk storage self, bytes calldata sourcePath, bytes calldata targetPath, uint curdir) external onlyOwner(self) {
    FileSystemLib.ResolvedPath memory source = self.pathToInode2(sourcePath, curdir, false);
    require(source.ino > 0, 'ENOENT');
    bool sourceIsDir = self.inode[source.ino].fileType == FileSystem.FileType.Directory;
    FileSystemLib.ResolvedPath memory target = self.pathToInode2(targetPath, curdir, true);
    if (source.ino == target.ino) return;
    if (target.ino > 0) {
      FileSystemLib.Inode storage inode = self.inode[target.ino];
      if (inode.fileType == FileSystem.FileType.Directory) {
        if (target.ino == source.dirIno) return;
        target.dirIno = target.ino;
        target.key = source.key;
      } else {
        require(!sourceIsDir, 'ENOTDIR');
        self.removeFromInode(target.dirIno, target.key);
        if (--inode.links == 0) self.freeInode(target.ino);
      }
    } else if (!sourceIsDir) {
      require(targetPath[targetPath.length-1] != '/', 'ENOENT');
    }
    if (sourceIsDir) {
      uint ino = target.dirIno;
      while (true) {
        require(ino != source.ino, 'EINVAL');
        if (ino == 1) break;
        ino = self.inodeValue[self.inode[ino].data['..']].value;
      }
      self.writeToInode(source.ino, '..', target.dirIno);
    }
    self.removeFromInode(source.dirIno, source.key);
    self.writeToInode(target.dirIno, target.key, source.ino);
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
        ino = self.inodeValue[self.inode[ino].data['..']].value;
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
        self.freeInoExtent.push(inode2.data[key]);
        delete inode2.data[key];
      }
      i = 0;
    }
    inode2.lastModified = inode.lastModified;
    inode2.keys.length = inode.keys.length;
    for (; i < inode.keys.length; i++) {
      bytes storage key = inode.keys[i];
      inode2.keys[i] = key;
      if (sourceIsDir) {
        inode2.data[key] = self.allocInodeValue();
        FileSystemLib.InodeValue storage data = self.inodeValue[inode.data[key]];
        FileSystemLib.InodeValue storage data2 = self.inodeValue[inode2.data[key]];
        data2.index = data.index;
        data2.value = self.allocInode();
        copyInode(self, self.inode[data.value], data2.value, ino);
      } else {
        inode2.data[key] = self.allocInodeExtent();
        self.inodeExtent[inode2.data[key]] = self.inodeExtent[inode.data[key]];
      }
    }
  }
}
