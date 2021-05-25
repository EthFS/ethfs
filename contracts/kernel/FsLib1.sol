// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.8;

import './FsLib.sol';

library FsLib1 {
  using FsLib for FsLib.Disk;

  modifier onlyOwner(FsLib.Disk storage self) {
    require(msg.sender == self.owner, 'EPERM');
    _;
  }

  function dirInodeToPath(FsLib.Disk storage self, uint ino_) external view onlyOwner(self) returns (bytes memory path) {
    uint ino = ino_;
    FsLib.Inode storage inode = self.inode[ino];
    require(inode.fileType == uint8(FileSystem.FileType.Directory), 'ENOTDIR');
    while (ino != 1) {
      uint dirIno = self.inodeValue[inode.data['..']].value;
      inode = self.inode[dirIno];
      self.checkMode(inode, 1);
      for (uint i;;) {
        bytes storage key = inode.keys[i++];
        if (self.inodeValue[inode.data[key]].value != ino) continue;
        bytes memory path2 = new bytes(key.length + path.length + 1);
        path2[0] = '/';
        uint k = 1;
        for (uint j; j < key.length;) path2[k++] = key[j++];
        for (uint j; j < path.length;) path2[k++] = path[j++];
        path = path2;
        break;
      }
      ino = dirIno;
    }
    if (path.length == 0) path = '/';
  }

  function link(FsLib.Disk storage self, bytes calldata source, bytes calldata target, uint curdir) external onlyOwner(self) {
    (uint ino,, bytes memory key) = self.pathToInode(source, curdir, 2);
    require(ino > 0, 'ENOENT');
    FsLib.Inode storage inode = self.inode[ino];
    require(inode.fileType != uint8(FileSystem.FileType.Directory), 'EISDIR');
    (uint ino2, uint dirIno, bytes memory key2) = self.pathToInode(target, curdir, 2);
    if (ino2 > 0) {
      require(self.inode[ino2].fileType == uint8(FileSystem.FileType.Directory), 'EEXIST');
      dirIno = ino2;
    } else {
      key = key2;
    }
    require(self.inode[dirIno].data[key] == 0, 'EEXIST');
    self.writeToInode(dirIno, key, ino);
    inode.links++;
  }

  function symlink(FsLib.Disk storage self, bytes calldata source, bytes calldata target, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = self.pathToInode(target, curdir, 1);
    require(ino == 0, 'EEXIST');
    ino = self.allocInode();
    FsLib.Inode storage inode = self.inode[ino];
    inode.fileType = uint8(FileSystem.FileType.Symlink);
    inode.mode = 511;
    inode.links = 1;
    inode.owner = inode.group = tx.origin;
    inode.lastModified = uint64(block.timestamp);
    uint inoExtent = self.allocInodeExtent();
    inode.data[''] = inoExtent;
    inode.keys.push('');
    FsLib.InodeExtent storage data = self.inodeExtent[inoExtent];
    data.index = 1;
    data.extent = source;
    self.writeToInode(dirIno, key, ino);
  }

  function readlink(FsLib.Disk storage self, bytes calldata path, uint curdir) external view onlyOwner(self) returns (bytes memory) {
    (uint ino,,) = self.pathToInode(path, curdir, 1);
    require(ino > 0, 'ENOENT');
    FsLib.Inode storage inode = self.inode[ino];
    require(inode.fileType == uint8(FileSystem.FileType.Symlink), 'EINVAL');
    return self.inodeExtent[inode.data['']].extent;
  }

  function move(FsLib.Disk storage self, bytes calldata sourcePath, bytes calldata targetPath, uint curdir) external onlyOwner(self) {
    FsLib.ResolvedPath memory source = self.pathToInode2(sourcePath, curdir, 1);
    require(source.ino > 0, 'ENOENT');
    bool sourceIsDir = self.inode[source.ino].fileType == uint8(FileSystem.FileType.Directory);
    FsLib.ResolvedPath memory target = self.pathToInode2(targetPath, curdir, 2);
    if (source.ino == target.ino) return;
    if (target.ino > 0) {
      FsLib.Inode storage inode = self.inode[target.ino];
      if (inode.fileType == uint8(FileSystem.FileType.Directory)) {
        target.dirIno = target.ino;
        target.key = source.key;
        if (target.dirIno == source.dirIno) return;
        if (inode.data[target.key] > 0) {
          uint ino = self.inodeValue[inode.data[target.key]].value;
          inode = self.inode[ino];
          if (sourceIsDir) {
            require(inode.fileType == uint8(FileSystem.FileType.Directory), 'ENOTDIR');
            require(inode.keys.length == 2, 'ENOTEMPTY');
            if (--inode.refCnt == 0) self.freeInode(ino);
          } else {
            require(inode.fileType != uint8(FileSystem.FileType.Directory), 'EISDIR');
            if (--inode.links == 0) self.freeInode(ino);
          }
        }
      } else {
        require(!sourceIsDir, 'ENOTDIR');
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

  function copy(FsLib.Disk storage self, bytes calldata sourcePath, bytes calldata targetPath, uint curdir) external onlyOwner(self) {
    FsLib.ResolvedPath memory source = self.pathToInode2(sourcePath, curdir, 2);
    require(source.ino > 0, 'ENOENT');
    FsLib.Inode storage inode = self.inode[source.ino];
    bool sourceIsDir = inode.fileType == uint8(FileSystem.FileType.Directory);
    FsLib.ResolvedPath memory target = self.pathToInode2(targetPath, curdir, 2);
    if (source.ino == target.ino) return;
    if (sourceIsDir) {
      uint ino = target.dirIno;
      while (true) {
        require(ino != source.ino, 'EINVAL');
        if (ino == 1) break;
        ino = self.inodeValue[self.inode[ino].data['..']].value;
      }
    } else if (target.ino == 0) {
      require(targetPath[targetPath.length-1] != '/', 'ENOENT');
    }
    _copy(self, source, target);
  }

  function _copy(FsLib.Disk storage self, FsLib.ResolvedPath memory source, FsLib.ResolvedPath memory target) private {
    FsLib.Inode storage inode = self.inode[source.ino];
    bool sourceIsDir = inode.fileType == uint8(FileSystem.FileType.Directory);
    uint newIno;
    if (target.ino > 0) {
      FsLib.Inode storage inode2 = self.inode[target.ino];
      if (inode2.fileType == uint8(FileSystem.FileType.Directory)) {
        target.dirIno = target.ino;
        target.key = source.key;
        if (target.dirIno == source.dirIno) return;
        self.checkMode(inode2, 1);
        if (inode2.data[target.key] > 0) {
          uint ino = self.inodeValue[inode2.data[target.key]].value;
          inode2 = self.inode[ino];
          if (sourceIsDir) {
            require(inode2.fileType == uint8(FileSystem.FileType.Directory), 'ENOTDIR');
            self.checkMode(inode2, 3);
            newIno = ino;
          } else {
            require(inode2.fileType != uint8(FileSystem.FileType.Directory), 'EISDIR');
            if (--inode2.links == 0 && inode2.refCnt == 0) {
              newIno = ino;
            }
          }
        }
      } else {
        require(!sourceIsDir, 'ENOTDIR');
        if (--inode2.links == 0 && inode2.refCnt == 0) {
          newIno = target.ino;
        }
      }
    }
    if (newIno == 0) {
      newIno = self.allocInode();
      self.writeToInode(target.dirIno, target.key, newIno);
    } else {
      self.checkMode(self.inode[target.dirIno], 2);
    }
    copyInode(self, source.ino, newIno, target.dirIno);
  }

  function copyInode(FsLib.Disk storage self, uint ino, uint ino2, uint dirIno) private {
    FsLib.Inode storage inode = self.inode[ino];
    FsLib.Inode storage inode2 = self.inode[ino2];
    bool sourceIsDir = inode.fileType == uint8(FileSystem.FileType.Directory);
    self.checkMode(inode, sourceIsDir ? 5 : 4);
    if (!sourceIsDir || inode2.keys.length == 0) {
      inode2.fileType = inode.fileType;
      inode2.mode = inode.mode;
      inode2.owner = inode.owner;
      inode2.group = inode.group;
    }
    uint i;
    if (sourceIsDir) {
      if (inode2.keys.length == 0) {
        inode2.refCnt = 1;
        self.writeToInode(ino2, '.', ino2);
        self.writeToInode(ino2, '..', dirIno);
      }
      i = 2;
    } else {
      inode2.links = 1;
      while (i < inode2.keys.length) {
        bytes storage key = inode2.keys[i++];
        self.freeInoExtent.push(inode2.data[key]);
        delete inode2.data[key];
      }
      delete inode2.keys;
      i = 0;
    }
    inode2.lastModified = inode.lastModified;
    while (i < inode.keys.length) {
      bytes storage key = inode.keys[i++];
      if (inode2.data[key] == 0) {
        inode2.keys.push(key);
        if (sourceIsDir) {
          inode2.data[key] = self.allocInodeValue();
          FsLib.InodeValue storage data = self.inodeValue[inode.data[key]];
          FsLib.InodeValue storage data2 = self.inodeValue[inode2.data[key]];
          data2.index = inode2.keys.length;
          data2.value = self.allocInode();
          copyInode(self, data.value, data2.value, ino2);
        } else {
          inode2.data[key] = self.allocInodeExtent();
          self.inodeExtent[inode2.data[key]] = self.inodeExtent[inode.data[key]];
        }
      } else {
        // sourceIsDir == true
        FsLib.InodeValue storage data = self.inodeValue[inode.data[key]];
        _copy(self, FsLib.ResolvedPath({ino: data.value, dirIno: ino, key: key}), FsLib.ResolvedPath({ino: ino2, dirIno: ino2, key: key}));
      }
    }
  }
}
