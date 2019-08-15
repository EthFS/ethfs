pragma solidity >= 0.5.8;

import './FsLib0.sol';

library FsLib1 {
  using FsLib for FsLib.Disk;

  modifier onlyOwner(FsLib.Disk storage self) {
    require(msg.sender == self.owner, 'EPERM');
    _;
  }

  function chown(FsLib.Disk storage self, bytes calldata path, address owner, address group, uint curdir) external onlyOwner(self) {
    (uint ino,,) = self.pathToInode(path, curdir, 2);
    require(ino > 0, 'ENOENT');
    FsLib.Inode storage inode = self.inode[ino];
    require(tx.origin == inode.owner, 'EACCES');
    if (owner != 0x0000000000000000000000000000000000000000) {
      inode.owner = owner;
    }
    if (group != 0x0000000000000000000000000000000000000000) {
      inode.group = group;
    }
  }

  function chmod(FsLib.Disk storage self, bytes calldata path, uint mode, uint curdir) external onlyOwner(self) {
    (uint ino,,) = self.pathToInode(path, curdir, 2);
    require(ino > 0, 'ENOENT');
    FsLib.Inode storage inode = self.inode[ino];
    require(tx.origin == inode.owner, 'EACCES');
    inode.mode = mode & 511;
  }

  function link(FsLib.Disk storage self, bytes calldata source, bytes calldata target, uint curdir) external onlyOwner(self) {
    (uint ino,, bytes memory key) = self.pathToInode(source, curdir, 2);
    require(ino > 0, 'ENOENT');
    FsLib.Inode storage inode = self.inode[ino];
    require(inode.fileType != FileSystem.FileType.Directory, 'EISDIR');
    (uint ino2, uint dirIno, bytes memory key2) = self.pathToInode(target, curdir, 2);
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

  function unlink(FsLib.Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = self.pathToInode(path, curdir, 1);
    require(ino > 0, 'ENOENT');
    FsLib.Inode storage inode = self.inode[ino];
    require(inode.fileType != FileSystem.FileType.Directory, 'EISDIR');
    self.removeFromInode(dirIno, key);
    if (--inode.links == 0) self.freeInode(ino);
  }

  function symlink(FsLib.Disk storage self, bytes calldata source, bytes calldata target, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = self.pathToInode(target, curdir, 1);
    require(ino == 0, 'EEXIST');
    ino = self.allocInode();
    FsLib.Inode storage inode = self.inode[ino];
    inode.fileType = FileSystem.FileType.Symlink;
    inode.mode = 511;
    inode.links = 1;
    inode.owner = inode.group = tx.origin;
    inode.lastModified = now;
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
    require(inode.fileType == FileSystem.FileType.Symlink, 'EINVAL');
    return self.inodeExtent[inode.data['']].extent;
  }

  function move(FsLib.Disk storage self, bytes calldata sourcePath, bytes calldata targetPath, uint curdir) external onlyOwner(self) {
    FsLib.ResolvedPath memory source = self.pathToInode2(sourcePath, curdir, 1);
    require(source.ino > 0, 'ENOENT');
    bool sourceIsDir = self.inode[source.ino].fileType == FileSystem.FileType.Directory;
    FsLib.ResolvedPath memory target = self.pathToInode2(targetPath, curdir, 2);
    if (source.ino == target.ino) return;
    if (target.ino > 0) {
      FsLib.Inode storage inode = self.inode[target.ino];
      if (inode.fileType == FileSystem.FileType.Directory) {
        target.dirIno = target.ino;
        target.key = source.key;
        if (target.dirIno == source.dirIno) return;
        if (inode.data[target.key] > 0) {
          uint ino = self.inodeValue[inode.data[target.key]].value;
          inode = self.inode[ino];
          if (sourceIsDir) {
            require(inode.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
            require(inode.keys.length == 2, 'ENOTEMPTY');
            if (--inode.refCnt == 0) self.freeInode(ino);
          } else {
            require(inode.fileType != FileSystem.FileType.Directory, 'EISDIR');
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
    bool sourceIsDir = inode.fileType == FileSystem.FileType.Directory;
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
    bool sourceIsDir = inode.fileType == FileSystem.FileType.Directory;
    uint newIno;
    if (target.ino > 0) {
      FsLib.Inode storage inode2 = self.inode[target.ino];
      if (inode2.fileType == FileSystem.FileType.Directory) {
        target.dirIno = target.ino;
        target.key = source.key;
        if (target.dirIno == source.dirIno) return;
        if (inode2.data[target.key] > 0) {
          uint ino = self.inodeValue[inode2.data[target.key]].value;
          inode2 = self.inode[ino];
          if (sourceIsDir) {
            require(inode2.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
            require(tx.origin == inode2.owner, 'EACCES');
            newIno = ino;
          } else {
            require(inode2.fileType != FileSystem.FileType.Directory, 'EISDIR');
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
    }
    copyInode(self, source.ino, newIno, target.dirIno);
  }

  function copyInode(FsLib.Disk storage self, uint ino, uint ino2, uint dirIno) private {
    FsLib.Inode storage inode = self.inode[ino];
    FsLib.Inode storage inode2 = self.inode[ino2];
    bool sourceIsDir = inode.fileType == FileSystem.FileType.Directory;
    if (!sourceIsDir || inode2.keys.length == 0) {
      inode2.fileType = inode.fileType;
      inode2.mode = inode.mode;
      inode2.owner = inode.owner;
      inode2.group = inode.group;
    }
    uint i;
    uint j;
    if (sourceIsDir) {
      j = inode2.keys.length;
      if (j == 0) {
        inode2.refCnt = 1;
        self.writeToInode(ino2, '.', ino2);
        self.writeToInode(ino2, '..', dirIno);
        inode2.keys.length = inode.keys.length;
        j = 2;
      } else {
        uint k;
        for (i = 2; i < inode.keys.length;) {
          if (inode2.data[inode.keys[i++]] == 0) k++;
        }
        inode2.keys.length = j+k;
      }
      i = 2;
    } else {
      inode2.links = 1;
      while (i < inode2.keys.length) {
        bytes storage key = inode2.keys[i++];
        self.freeInoExtent.push(inode2.data[key]);
        delete inode2.data[key];
      }
      inode2.keys.length = inode.keys.length;
      i = 0;
    }
    inode2.lastModified = inode.lastModified;
    while (i < inode.keys.length) {
      bytes storage key = inode.keys[i++];
      if (inode2.data[key] == 0) {
        inode2.keys[j++] = key;
        if (sourceIsDir) {
          inode2.data[key] = self.allocInodeValue();
          FsLib.InodeValue storage data = self.inodeValue[inode.data[key]];
          FsLib.InodeValue storage data2 = self.inodeValue[inode2.data[key]];
          data2.index = j;
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
