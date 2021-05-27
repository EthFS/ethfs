// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.8;

import 'bytes/BytesLib.sol';
import '../interface/Constants.sol';
import '../interface/FileSystem.sol';
import '../interface/Group.sol';

library FsLib {
  struct Disk {
    address owner;
    Inode[] inode;
    InodeValue[] inodeValue;
    InodeExtent[] inodeExtent;
    uint[] freeIno;
    uint[] freeInoValue;
    uint[] freeInoExtent;
  }

  struct Inode {
    uint8 fileType;
    uint16 mode;
    uint32 links;
    uint32 refCnt;
    address owner;
    address group;
    uint64 lastModified;
    bytes[] keys;
    mapping(bytes => uint) data;
  }

  struct InodeValue {
    uint index;
    uint value;
  }

  struct InodeExtent {
    uint index;
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
    self.inode.push();
    self.inode.push();
    self.inodeValue.push();
    self.inodeExtent.push();
    self.inode[ino].fileType = uint8(FileSystem.FileType.Directory);
    self.inode[ino].mode = 493;
    self.inode[ino].owner = tx.origin;
    self.inode[ino].group = tx.origin;
    self.inode[ino].refCnt = 1;
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

  function pathToInode(Disk storage self, bytes memory path, uint curdir, uint followLinks) public view returns (uint ino, uint dirIno, bytes memory key) {
    require(path.length > 0, 'ENOENT');
    ino = path[0] == '/' ? 1 : curdir == 0 ? 1 : curdir;
    uint j;
    for (uint i; i <= path.length; i++) {
      while (i < path.length && path[i] != '/') i++;
      if (i == j) {
        j++;
        continue;
      }
      require(ino > 0, 'ENOENT');
      Inode storage inode = self.inode[ino];
      if (followLinks > 0 && inode.fileType == uint8(FileSystem.FileType.Symlink)) {
        (ino,,) = pathToInode(self, self.inodeExtent[inode.data['']].extent, dirIno, 2);
        require(ino > 0, 'ENOENT');
        inode = self.inode[ino];
      }
      require(inode.fileType == uint8(FileSystem.FileType.Directory), 'ENOTDIR');
      checkMode(self, inode, 1);
      key = new bytes(i-j);
      for (uint k; j < i;) key[k++] = path[j++];
      j++;
      dirIno = ino;
      ino = self.inodeValue[inode.data[key]].value;
    }
    if (ino > 0 && followLinks > 1) {
      Inode storage inode = self.inode[ino];
      if (inode.fileType == uint8(FileSystem.FileType.Symlink)) {
        (ino, dirIno, key) = pathToInode(self, self.inodeExtent[inode.data['']].extent, dirIno, 2);
      }
    }
    if (ino == 0) {
      require(path[path.length-1] != '/', 'ENOENT');
    } else if (self.inode[ino].fileType != uint8(FileSystem.FileType.Directory)) {
      require(path[path.length-1] != '/', 'ENOTDIR');
    }
    if (key.length == 1 && key[0] == '.' ||
        key.length == 2 && key[0] == '.' && key[1] == '.') {
      dirIno = self.inodeValue[self.inode[ino].data['..']].value;
      Inode storage inode = self.inode[dirIno];
      for (uint i;;) {
        bytes storage key2 = inode.keys[i++];
        if (self.inodeValue[inode.data[key2]].value == ino) {
          key = key2;
          break;
        }
      }
    }
  }

  function pathToInode2(Disk storage self, bytes memory path, uint curdir, uint followLinks) internal view returns (ResolvedPath memory) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, followLinks);
    return ResolvedPath(ino, dirIno, key);
  }

  function allocInode(Disk storage self) public returns (uint ino) {
    if (self.freeIno.length > 0) {
      ino = self.freeIno[self.freeIno.length-1];
      self.freeIno.pop();
    } else {
      ino = self.inode.length;
      self.inode.push();
    }
  }

  function freeInode(Disk storage self, uint ino) public {
    Inode storage inode = self.inode[ino];
    if (inode.links + inode.refCnt > 0) return;
    bool isDir = inode.fileType == uint8(FileSystem.FileType.Directory);
    for (uint i; i < inode.keys.length;) {
      bytes storage key = inode.keys[i++];
      if (isDir) {
        self.freeInoValue.push(inode.data[key]);
      } else {
        self.freeInoExtent.push(inode.data[key]);
      }
      delete inode.data[key];
    }
    delete inode.keys;
    self.freeIno.push(ino);
  }

  function allocInodeValue(Disk storage self) public returns (uint index) {
    if (self.freeInoValue.length > 0) {
      index = self.freeInoValue[self.freeInoValue.length-1];
      self.freeInoValue.pop();
    } else {
      index = self.inodeValue.length;
      self.inodeValue.push();
    }
  }

  function allocInodeExtent(Disk storage self) public returns (uint index) {
    if (self.freeInoExtent.length > 0) {
      index = self.freeInoExtent[self.freeInoExtent.length-1];
      self.freeInoExtent.pop();
    } else {
      index = self.inodeExtent.length;
      self.inodeExtent.push();
    }
  }

  function writeToInode(Disk storage self, uint ino, bytes memory key, uint value) public {
    Inode storage inode = self.inode[ino];
    checkMode(self, inode, 2);
    if (inode.data[key] == 0) {
      inode.data[key] = allocInodeValue(self);
      InodeValue storage data = self.inodeValue[inode.data[key]];
      inode.keys.push(key);
      data.index = inode.keys.length;  // index+1
      data.value = value;
    } else {
      self.inodeValue[inode.data[key]].value = value;
    }
    inode.lastModified = uint64(block.timestamp);
  }

  function removeFromInode(Disk storage self, uint ino, bytes memory key) public {
    Inode storage inode = self.inode[ino];
    checkMode(self, inode, 2);
    bytes[] storage keys = inode.keys;
    uint inoValue = inode.data[key];
    uint index = self.inodeValue[inoValue].index-1;
    if (index < keys.length-1) {
      bytes storage key2 = keys[keys.length-1];
      keys[index] = key2;
      self.inodeValue[inode.data[key2]].index = index+1;
    }
    keys.pop();
    self.freeInoValue.push(inoValue);
    delete inode.data[key];
    inode.lastModified = uint64(block.timestamp);
  }

  function checkMode(Disk storage, Inode storage inode, uint mask) public view {
    uint16 mode;
    if (tx.origin == inode.owner) {
      mode = inode.mode >> 6 & 7;
    } else if (inode.group != inode.owner && Group(inode.group).contains(tx.origin)) {
      mode = inode.mode >> 3 & 7;
    } else {
      mode = inode.mode & 7;
    }
    require(mode & mask == mask, 'EACCES');
  }

  function checkOpen(Disk storage self, uint ino, uint flags) private view {
    require(ino > 0, 'ENOENT');
    Inode storage inode = self.inode[ino];
    uint accmode = flags & Constants.O_ACCMODE();
    if (accmode == Constants.O_RDONLY()) {
      checkMode(self, inode, 4);
    } else if (accmode == Constants.O_WRONLY()) {
      checkMode(self, inode, 2);
    } else if (accmode == Constants.O_RDWR()) {
      checkMode(self, inode, 6);
    }
    if (flags & Constants.O_DIRECTORY() > 0) {
      require(inode.fileType == uint8(FileSystem.FileType.Directory), 'ENOTDIR');
    }
  }

  function open(Disk storage self, bytes calldata path, uint curdir, uint flags) external onlyOwner(self) returns (uint) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, flags & Constants.O_NOFOLLOW() == 0 ? 2 : 0);
    if (flags & Constants.O_CREAT() > 0) {
      if (ino > 0) {
        require(flags & Constants.O_EXCL() == 0, 'EEXIST');
      } else {
        ino = allocInode(self);
        Inode storage inode = self.inode[ino];
        inode.fileType = uint8(FileSystem.FileType.Regular);
        inode.mode = 420;
        inode.links = 1;
        inode.owner = inode.group = tx.origin;
        inode.lastModified = uint64(block.timestamp);
        writeToInode(self, dirIno, key, ino);
      }
    }
    checkOpen(self, ino, flags);
    self.inode[ino].refCnt++;
    return ino;
  }

  function openOnly(Disk storage self, bytes calldata path, uint curdir, uint flags) external view onlyOwner(self) returns (uint ino) {
    (ino,,) = pathToInode(self, path, curdir, flags & Constants.O_NOFOLLOW() == 0 ? 2 : 0);
    checkOpen(self, ino, flags);
  }

  function close(Disk storage self, uint ino) external onlyOwner(self) {
    if (--self.inode[ino].refCnt == 0) freeInode(self, ino);
  }

  function readkey(Disk storage self, uint ino, uint index) external view onlyOwner(self) returns (bytes memory) {
    return self.inode[ino].keys[index];
  }

  function read(Disk storage self, uint ino, bytes calldata key) external view onlyOwner(self) returns (bytes memory) {
    uint index = self.inode[ino].data[key];
    require(index > 0, 'EINVAL');
    return self.inodeExtent[index].extent;
  }

  function write(Disk storage self, uint ino, bytes calldata key, bytes calldata value) external onlyOwner(self) {
    Inode storage inode = self.inode[ino];
    require(inode.fileType == uint8(FileSystem.FileType.Regular), 'EPERM');
    uint inoExtent = inode.data[key];
    if (inoExtent == 0) {
      inoExtent = allocInodeExtent(self);
      inode.data[key] = inoExtent;
      inode.keys.push(key);
      InodeExtent storage data = self.inodeExtent[inoExtent];
      data.index = inode.keys.length;  // index+1
      data.extent = value;
    } else {
      BytesLib.concatStorage(self.inodeExtent[inoExtent].extent, value);
    }
    inode.lastModified = uint64(block.timestamp);
  }

  function truncate(Disk storage self, uint ino, bytes calldata key, uint len) external onlyOwner(self) {
    Inode storage inode = self.inode[ino];
    require(inode.fileType == uint8(FileSystem.FileType.Regular), 'EPERM');
    uint inoExtent = inode.data[key];
    if (inoExtent == 0) {
      require(len == 0, 'EINVAL');
      return;
    }
    bytes storage extent = self.inodeExtent[inoExtent].extent;
    while (extent.length > len) {
      if (extent.length > 32) {
        assembly { sstore(extent.slot, 65) }
      } else {
        extent.pop();
      }
    }
    while (extent.length < len) {
      if (extent.length < 32) {
        extent.push();
      } else {
        assembly { sstore(extent.slot, add(mul(len, 2), 1)) }
      }
    }
    if (len >= 32) {
      assembly {
        mstore(0x0, extent.slot)
        let sc := add(keccak256(0x0, 0x20), div(len, 32))
        let submod := sub(32, mod(len, 32))
        let mask := not(sub(exp(0x100, submod), 1))
        sstore(sc, and(sload(sc), mask))
      }
    }
    inode.lastModified = uint64(block.timestamp);
  }

  function clear(Disk storage self, uint ino, bytes calldata key) external onlyOwner(self) {
    Inode storage inode = self.inode[ino];
    require(inode.fileType == uint8(FileSystem.FileType.Regular), 'EPERM');
    uint inoExtent = inode.data[key];
    require(inoExtent > 0, 'EINVAL');
    bytes[] storage keys = inode.keys;
    uint index = self.inodeExtent[inoExtent].index-1;
    if (index < keys.length-1) {
      bytes storage key2 = keys[keys.length-1];
      keys[index] = key2;
      self.inodeExtent[inode.data[key2]].index = index+1;
    }
    keys.pop();
    self.freeInoExtent.push(inoExtent);
    delete inode.data[key];
    inode.lastModified = uint64(block.timestamp);
  }

  function stat(Disk storage self, bytes calldata path, uint curdir) external view onlyOwner(self) returns (FileSystem.FileType fileType, uint16 mode, uint ino_, uint links, address owner, address group, uint entries, uint size, uint lastModified) {
    (uint ino,,) = pathToInode(self, path, curdir, 2);
    require(ino > 0, 'ENOENT');
    return _fstat(self, ino);
  }

  function lstat(Disk storage self, bytes calldata path, uint curdir) external view onlyOwner(self) returns (FileSystem.FileType fileType, uint16 mode, uint ino_, uint links, address owner, address group, uint entries, uint size, uint lastModified) {
    (uint ino,,) = pathToInode(self, path, curdir, 1);
    require(ino > 0, 'ENOENT');
    return _fstat(self, ino);
  }

  function fstat(Disk storage self, uint ino) external view onlyOwner(self) returns (FileSystem.FileType fileType, uint16 mode, uint ino_, uint links, address owner, address group, uint entries, uint size, uint lastModified) {
    return _fstat(self, ino);
  }

  function _fstat(Disk storage self, uint ino) private view returns (FileSystem.FileType fileType, uint16 mode, uint ino_, uint links, address owner, address group, uint entries, uint size, uint lastModified) {
    Inode storage inode = self.inode[ino];
    fileType = FileSystem.FileType(inode.fileType);
    mode = inode.mode;
    if (fileType == FileSystem.FileType.Directory) {
      mode |= 0x4000;
      links = inode.keys.length;
    } else {
      if (fileType == FileSystem.FileType.Regular) {
        mode |= 0x8000;
      } else if (fileType == FileSystem.FileType.Symlink) {
        mode |= 0xa000;
      }
      links = inode.links;
      uint inoExtent = inode.data[''];
      if (inoExtent > 0) {
        size = self.inodeExtent[inoExtent].extent.length;
      }
    }
    ino_ = ino;
    owner = inode.owner;
    group = inode.group;
    entries = inode.keys.length;
    lastModified = inode.lastModified;
  }

  function mkdir(Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, 1);
    require(ino == 0, 'EEXIST');
    ino = allocInode(self);
    Inode storage inode = self.inode[ino];
    inode.fileType = uint8(FileSystem.FileType.Directory);
    inode.mode = 493;
    inode.owner = inode.group = tx.origin;
    inode.refCnt = 1;
    writeToInode(self, dirIno, key, ino);
    writeToInode(self, ino, '.', ino);
    writeToInode(self, ino, '..', dirIno);
  }

  function rmdir(Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, 1);
    require(ino > 0, 'ENOENT');
    require(ino != 1 && ino != curdir, 'EBUSY');
    Inode storage inode = self.inode[ino];
    require(inode.fileType == uint8(FileSystem.FileType.Directory), 'ENOTDIR');
    require(inode.keys.length == 2, 'ENOTEMPTY');
    removeFromInode(self, dirIno, key);
    if (--inode.refCnt == 0) freeInode(self, ino);
  }

  function unlink(Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, 1);
    require(ino > 0, 'ENOENT');
    Inode storage inode = self.inode[ino];
    require(inode.fileType != uint8(FileSystem.FileType.Directory), 'EISDIR');
    removeFromInode(self, dirIno, key);
    if (--inode.links == 0) freeInode(self, ino);
  }

  function chown(Disk storage self, bytes calldata path, address owner, address group, uint curdir) external onlyOwner(self) {
    (uint ino,,) = pathToInode(self, path, curdir, 2);
    require(ino > 0, 'ENOENT');
    Inode storage inode = self.inode[ino];
    require(tx.origin == inode.owner, 'EACCES');
    if (owner != 0x0000000000000000000000000000000000000000) {
      inode.owner = owner;
    }
    if (group != 0x0000000000000000000000000000000000000000) {
      inode.group = group;
    }
  }

  function chmod(Disk storage self, bytes calldata path, uint16 mode, uint curdir) external onlyOwner(self) {
    (uint ino,,) = pathToInode(self, path, curdir, 2);
    require(ino > 0, 'ENOENT');
    Inode storage inode = self.inode[ino];
    require(tx.origin == inode.owner, 'EACCES');
    inode.mode = mode & 511;
  }
}
