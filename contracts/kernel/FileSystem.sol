pragma solidity >= 0.5.8;

import '../interface/FileSystem.sol';

library FileSystemLib {
  uint constant O_RDONLY  = 0x0000;
  uint constant O_WRONLY  = 0x0001;
  uint constant O_RDWR    = 0x0002;
  uint constant O_ACCMODE = 0x0003;

  uint constant O_CREAT = 0x0100;
  uint constant O_EXCL  = 0x0200;

  uint constant O_DIRECTORY = 0x00200000;

  struct Disk {
    address owner;
    Inode[] inode;
    InodeData[] inodeData;
    uint[] freeIno;
    uint[] freeInoData;
  }

  struct Inode {
    address owner;
    FileSystem.FileType fileType;
    uint permissions;
    uint lastModified;
    uint links;
    uint refCnt;
    bytes[] keys;
    mapping(bytes => uint) data;
  }

  struct InodeData {
    uint index;
    uint value;
    bytes extent;
  }

  struct ResolvedPath {
    uint ino;
    uint dirIno;
    bytes key;
  }

  modifier onlyOwner(Disk storage self) {
    require(msg.sender == self.owner, 'EPERM');
    _;
  }

  function init(Disk storage self) external {
    // Set up root inode
    uint ino = 1;
    self.inode.length = ino+1;
    self.inodeData.length = 1;
    self.inode[ino].owner = tx.origin;
    self.inode[ino].fileType = FileSystem.FileType.Directory;
    writeToInode(self, ino, '.', ino);
    writeToInode(self, ino, '..', ino);
  }

  function mount(Disk storage self) external {
    require(self.owner == address(0), 'EPERM');
    self.owner = msg.sender;
  }

  function unmount(Disk storage self) external onlyOwner(self) {
    self.owner = address(0);
  }

  function pathToInode(Disk storage self, bytes memory path, uint curdir, bool allowNonExistDir) private view returns (uint ino, uint dirIno, bytes memory key) {
    require(path.length > 0, 'ENOENT');
    if (curdir == 0) curdir = 1;
    ino = path[0] == '/' ? 1 : curdir;
    uint j;
    for (uint i = 0; i <= path.length; i++) {
      while (i < path.length && path[i] != '/') i++;
      if (i == j) {
        j++;
        continue;
      }
      require(ino > 0, 'ENOENT');
      Inode storage inode = self.inode[ino];
      require(inode.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
      require(tx.origin == inode.owner, 'EACCES');
      key = new bytes(i-j);
      for (uint k; j < i;) key[k++] = path[j++];
      j++;
      dirIno = ino;
      ino = self.inodeData[inode.data[key]].value;
    }
    if (ino == 0) {
      require(allowNonExistDir || path[path.length-1] != '/', 'ENOENT');
    } else if (self.inode[ino].fileType != FileSystem.FileType.Directory) {
      require(path[path.length-1] != '/', 'ENOTDIR');
    }
    if (key.length == 1 && key[0] == '.' ||
        key.length == 2 && key[0] == '.' && key[1] == '.') {
      dirIno = self.inodeData[self.inode[ino].data['..']].value;
      Inode storage inode = self.inode[dirIno];
      for (uint i;;) {
        bytes storage key2 = inode.keys[i++];
        if (self.inodeData[inode.data[key2]].value == ino) {
          key = key2;
          break;
        }
      }
    }
  }

  function pathToInode2(Disk storage self, bytes memory path, uint curdir, bool allowNonExistDir) private view returns (ResolvedPath memory) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, allowNonExistDir);
    return ResolvedPath(ino, dirIno, key);
  }

  function dirInodeToPath(Disk storage self, uint ino_) external view onlyOwner(self) returns (bytes memory path) {
    uint ino = ino_;
    Inode storage inode = self.inode[ino];
    require(inode.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
    while (ino != 1) {
      uint dirIno = self.inodeData[inode.data['..']].value;
      inode = self.inode[dirIno];
      require(tx.origin == inode.owner, 'EACCES');
      for (uint i;;) {
        bytes storage key = inode.keys[i++];
        if (self.inodeData[inode.data[key]].value != ino) continue;
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
    if (path.length == 0) {
      path = new bytes(1);
      path[0] = '/';
    }
  }

  function allocInode(Disk storage self) private returns(uint ino) {
    if (self.freeIno.length > 0) {
      ino = self.freeIno[self.freeIno.length-1];
      self.freeIno.pop();
    } else {
      ino = self.inode.length++;
    }
  }

  function freeInode(Disk storage self, uint ino) private {
    Inode storage inode = self.inode[ino];
    for (uint i; i < inode.keys.length;) {
      bytes storage key = inode.keys[i++];
      self.freeInoData.push(inode.data[key]);
      delete inode.data[key];
    }
    self.freeIno.push(ino);
  }

  function allocInodeData(Disk storage self) private returns(uint inoData) {
    if (self.freeInoData.length > 0) {
      inoData = self.freeInoData[self.freeInoData.length-1];
      self.freeInoData.pop();
    } else {
      inoData = self.inodeData.length++;
    }
  }

  function writeToInode(Disk storage self, uint ino, bytes memory key, uint value) private {
    Inode storage inode = self.inode[ino];
    if (inode.data[key] == 0) {
      inode.data[key] = allocInodeData(self);
      InodeData storage data = self.inodeData[inode.data[key]];
      inode.keys.push(key);
      data.index = inode.keys.length;  // index+1
      data.value = value;
    } else {
      self.inodeData[inode.data[key]].value = value;
    }
    inode.lastModified = now;
  }

  function removeFromInode(Disk storage self, uint ino, bytes memory key) private {
    Inode storage inode = self.inode[ino];
    bytes[] storage keys = inode.keys;
    uint inoData = inode.data[key];
    uint index = self.inodeData[inoData].index-1;
    if (index < keys.length-1) {
      bytes storage key2 = keys[keys.length-1];
      keys[index] = key2;
      self.inodeData[inode.data[key2]].index = index+1;
    }
    keys.pop();
    self.freeInoData.push(inoData);
    delete inode.data[key];
    inode.lastModified = now;
  }

  function checkOpen(Disk storage self, uint ino, uint flags) private view {
    require(ino > 0, 'ENOENT');
    Inode storage inode = self.inode[ino];
    require(tx.origin == inode.owner, 'EACCES');
    if (flags & O_DIRECTORY > 0) {
      require(inode.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
    }
  }

  function open(Disk storage self, bytes calldata path, uint curdir, uint flags) external onlyOwner(self) returns (uint) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, false);
    if (flags & O_CREAT > 0) {
      if (ino > 0) {
        require(flags & O_EXCL == 0, 'EEXIST');
      } else {
        ino = allocInode(self);
        Inode storage inode = self.inode[ino];
        inode.owner = tx.origin;
        inode.fileType = FileSystem.FileType.Data;
        inode.lastModified = now;
        inode.links = 1;
        writeToInode(self, dirIno, key, ino);
      }
    }
    checkOpen(self, ino, flags);
    return ino;
  }

  function openOnly(Disk storage self, bytes calldata path, uint curdir, uint flags) external view onlyOwner(self) returns (uint ino) {
    (ino,,) = pathToInode(self, path, curdir, false);
    checkOpen(self, ino, flags);
  }

  function readkey(Disk storage self, uint ino, uint index) external view onlyOwner(self) returns (bytes memory) {
    return self.inode[ino].keys[index];
  }

  function read(Disk storage self, uint ino, bytes calldata key) external view onlyOwner(self) returns (bytes memory) {
    uint inoData = self.inode[ino].data[key];
    require(inoData > 0, 'EINVAL');
    return self.inodeData[inoData].extent;
  }

  function write(Disk storage self, uint ino, bytes calldata key, bytes calldata value) external onlyOwner(self) {
    Inode storage inode = self.inode[ino];
    require(inode.fileType == FileSystem.FileType.Data, 'EPERM');
    if (inode.data[key] == 0) {
      inode.data[key] = allocInodeData(self);
      InodeData storage data = self.inodeData[inode.data[key]];
      inode.keys.push(key);
      data.index = inode.keys.length;  // index+1
      data.extent = value;
    } else {
      self.inodeData[inode.data[key]].extent = value;
    }
    inode.lastModified = now;
  }

  function clear(Disk storage self, uint ino, bytes calldata key) external onlyOwner(self) {
    Inode storage inode = self.inode[ino];
    require(inode.fileType == FileSystem.FileType.Data, 'EPERM');
    require(inode.data[key] > 0, 'EINVAL');
    removeFromInode(self, ino, key);
  }

  function link(Disk storage self, bytes calldata source, bytes calldata target, uint curdir) external onlyOwner(self) {
    (uint ino,, bytes memory key) = pathToInode(self, source, curdir, false);
    require(ino > 0, 'ENOENT');
    Inode storage inode = self.inode[ino];
    require(inode.fileType != FileSystem.FileType.Directory, 'EISDIR');
    (uint ino2, uint dirIno, bytes memory key2) = pathToInode(self, target, curdir, false);
    if (ino2 > 0) {
      require(self.inode[ino2].fileType == FileSystem.FileType.Directory, 'EEXIST');
      dirIno = ino2;
    } else {
      key = key2;
    }
    require(self.inode[dirIno].data[key] == 0, 'EEXIST');
    writeToInode(self, dirIno, key, ino);
    inode.links++;
  }

  function unlink(Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, false);
    require(ino > 0, 'ENOENT');
    Inode storage inode = self.inode[ino];
    require(inode.fileType != FileSystem.FileType.Directory, 'EISDIR');
    removeFromInode(self, dirIno, key);
    if (--inode.links == 0) freeInode(self, ino);
  }

  function move(Disk storage self, bytes calldata source, bytes calldata target, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, source, curdir, false);
    require(ino > 0, 'ENOENT');
    bool sourceIsDir = self.inode[ino].fileType == FileSystem.FileType.Directory;
    (uint ino2, uint dirIno2, bytes memory key2) = pathToInode(self, target, curdir, true);
    if (ino == ino2) return;
    if (ino2 > 0) {
      Inode storage inode = self.inode[ino2];
      if (inode.fileType == FileSystem.FileType.Directory) {
        if (ino2 == dirIno) return;
        dirIno2 = ino2;
        key2 = key;
      } else {
        require(!sourceIsDir, 'ENOTDIR');
        removeFromInode(self, dirIno2, key2);
        if (--inode.links == 0) freeInode(self, ino2);
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
      writeToInode(self, ino, '..', dirIno2);
    }
    removeFromInode(self, dirIno, key);
    writeToInode(self, dirIno2, key2, ino);
  }

  function copy(Disk storage self, bytes calldata sourcePath, bytes calldata targetPath, uint curdir) external onlyOwner(self) {
    ResolvedPath memory source = pathToInode2(self, sourcePath, curdir, false);
    require(source.ino > 0, 'ENOENT');
    Inode storage inode = self.inode[source.ino];
    bool sourceIsDir = inode.fileType == FileSystem.FileType.Directory;
    ResolvedPath memory target = pathToInode2(self, targetPath, curdir, true);
    if (source.ino == target.ino) return;
    uint newIno;
    if (target.ino > 0) {
      Inode storage inode2 = self.inode[target.ino];
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
      newIno = allocInode(self);
      writeToInode(self, target.dirIno, target.key, newIno);
    }
    copyInode(self, inode, newIno, target.dirIno);
  }

  function copyInode(Disk storage self, Inode storage inode, uint ino, uint dirIno) private {
    bool sourceIsDir = inode.fileType == FileSystem.FileType.Directory;
    Inode storage inode2 = self.inode[ino];
    inode2.owner = inode.owner;
    inode2.fileType = inode.fileType;
    inode2.permissions = inode.permissions;
    uint i;
    if (sourceIsDir) {
      i = 2;
      writeToInode(self, ino, '.', ino);
      writeToInode(self, ino, '..', dirIno);
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
      inode2.data[key] = allocInodeData(self);
      InodeData storage data = self.inodeData[inode.data[key]];
      InodeData storage data2 = self.inodeData[inode2.data[key]];
      data2.index = data.index;
      if (sourceIsDir) {
        data2.value = allocInode(self);
        copyInode(self, self.inode[data.value], data2.value, ino);
      } else {
        data2.extent = data.extent;
      }
    }
  }

  function install(Disk storage self, address source, bytes calldata target, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, target, curdir, false);
    require(ino == 0, 'EEXIST');
    ino = allocInode(self);
    Inode storage inode = self.inode[ino];
    inode.owner = source;
    inode.fileType = FileSystem.FileType.Contract;
    inode.lastModified = now;
    inode.links = 1;
    writeToInode(self, dirIno, key, ino);
  }

  function mkdir(Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, true);
    require(ino == 0, 'EEXIST');
    ino = allocInode(self);
    Inode storage inode = self.inode[ino];
    inode.owner = tx.origin;
    inode.fileType = FileSystem.FileType.Directory;
    writeToInode(self, dirIno, key, ino);
    writeToInode(self, ino, '.', ino);
    writeToInode(self, ino, '..', dirIno);
  }

  function rmdir(Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, false);
    require(ino > 0, 'ENOENT');
    require(ino != curdir, 'EINVAL');
    Inode storage inode = self.inode[ino];
    require(inode.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
    require(inode.keys.length == 2, 'ENOTEMPTY');
    removeFromInode(self, dirIno, key);
    freeInode(self, ino);
  }

  function stat(Disk storage self, bytes calldata path, uint curdir) external view onlyOwner(self) returns (FileSystem.FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint lastModified) {
    (uint ino, uint dirIno,) = pathToInode(self, path, curdir, false);
    require(ino > 0, 'ENOENT');
    if (dirIno == 0) dirIno = ino;
    checkOpen(self, dirIno, 0);
    return _fstat(self, ino);
  }

  function fstat(Disk storage self, uint ino) external view onlyOwner(self) returns (FileSystem.FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint lastModified) {
    return _fstat(self, ino);
  }

  function _fstat(Disk storage self, uint ino) private view returns (FileSystem.FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint lastModified) {
    Inode storage inode = self.inode[ino];
    fileType = inode.fileType;
    permissions = inode.permissions;
    ino_ = ino;
    device = address(this);
    links = inode.links;
    owner = inode.owner;
    entries = inode.keys.length;
    lastModified = inode.lastModified;
  }

  function readContract(Disk storage self, bytes calldata path, uint curdir) external view onlyOwner(self) returns (address) {
    (uint ino,,) = pathToInode(self, path, curdir, false);
    require(ino > 0, 'ENOENT');
    Inode storage inode = self.inode[ino];
    require(inode.fileType != FileSystem.FileType.Directory, 'EISDIR');
    require(inode.fileType == FileSystem.FileType.Contract, 'ENOEXEC');
    return inode.owner;
  }
}
