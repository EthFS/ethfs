pragma solidity >= 0.5.8;

import 'solidity-bytes-utils/contracts/BytesLib.sol';
import '../interface/Constants.sol';
import '../interface/FileSystem.sol';

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
    address owner;
    FileSystem.FileType fileType;
    uint permissions;
    uint lastModified;
    uint links;
    uint refCnt;
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
    self.inode.length = ino+1;
    self.inodeValue.length = 1;
    self.inodeExtent.length = 1;
    self.inode[ino].owner = tx.origin;
    self.inode[ino].fileType = FileSystem.FileType.Directory;
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
    for (uint i = 0; i <= path.length; i++) {
      while (i < path.length && path[i] != '/') i++;
      if (i == j) {
        j++;
        continue;
      }
      require(ino > 0, 'ENOENT');
      Inode storage inode = self.inode[ino];
      if (followLinks > 0 && inode.fileType == FileSystem.FileType.Symlink) {
        (ino,,) = pathToInode(self, self.inodeExtent[inode.data['']].extent, dirIno, 2);
        require(ino > 0, 'ENOENT');
        inode = self.inode[ino];
      }
      require(inode.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
      require(tx.origin == inode.owner, 'EACCES');
      key = new bytes(i-j);
      for (uint k; j < i;) key[k++] = path[j++];
      j++;
      dirIno = ino;
      ino = self.inodeValue[inode.data[key]].value;
    }
    if (ino > 0 && followLinks > 1) {
      Inode storage inode = self.inode[ino];
      if (inode.fileType == FileSystem.FileType.Symlink) {
        (ino, dirIno, key) = pathToInode(self, self.inodeExtent[inode.data['']].extent, dirIno, 2);
      }
    }
    if (ino == 0) {
      require(path[path.length-1] != '/', 'ENOENT');
    } else if (self.inode[ino].fileType != FileSystem.FileType.Directory) {
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

  function dirInodeToPath(Disk storage self, uint ino_) external view onlyOwner(self) returns (bytes memory path) {
    uint ino = ino_;
    Inode storage inode = self.inode[ino];
    require(inode.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
    while (ino != 1) {
      uint dirIno = self.inodeValue[inode.data['..']].value;
      inode = self.inode[dirIno];
      require(tx.origin == inode.owner, 'EACCES');
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
    if (path.length == 0) {
      path = new bytes(1);
      path[0] = '/';
    }
  }

  function allocInode(Disk storage self) public returns (uint ino) {
    if (self.freeIno.length > 0) {
      ino = self.freeIno[self.freeIno.length-1];
      self.freeIno.pop();
    } else {
      ino = self.inode.length++;
    }
  }

  function freeInode(Disk storage self, uint ino) public {
    Inode storage inode = self.inode[ino];
    if (inode.links + inode.refCnt > 0) return;
    bool isDir = inode.fileType == FileSystem.FileType.Directory;
    for (uint i; i < inode.keys.length;) {
      bytes storage key = inode.keys[i++];
      if (isDir) {
        self.freeInoValue.push(inode.data[key]);
      } else {
        self.freeInoExtent.push(inode.data[key]);
      }
      delete inode.data[key];
    }
    inode.keys.length = 0;
    self.freeIno.push(ino);
  }

  function allocInodeValue(Disk storage self) public returns (uint index) {
    if (self.freeInoValue.length > 0) {
      index = self.freeInoValue[self.freeInoValue.length-1];
      self.freeInoValue.pop();
    } else {
      index = self.inodeValue.length++;
    }
  }

  function allocInodeExtent(Disk storage self) public returns (uint index) {
    if (self.freeInoExtent.length > 0) {
      index = self.freeInoExtent[self.freeInoExtent.length-1];
      self.freeInoExtent.pop();
    } else {
      index = self.inodeExtent.length++;
    }
  }

  function writeToInode(Disk storage self, uint ino, bytes memory key, uint value) public {
    Inode storage inode = self.inode[ino];
    if (inode.data[key] == 0) {
      inode.data[key] = allocInodeValue(self);
      InodeValue storage data = self.inodeValue[inode.data[key]];
      inode.keys.push(key);
      data.index = inode.keys.length;  // index+1
      data.value = value;
    } else {
      self.inodeValue[inode.data[key]].value = value;
    }
    inode.lastModified = now;
  }

  function removeFromInode(Disk storage self, uint ino, bytes memory key) public {
    Inode storage inode = self.inode[ino];
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
    inode.lastModified = now;
  }

  function checkOpen(Disk storage self, uint ino, uint flags) private view {
    require(ino > 0, 'ENOENT');
    Inode storage inode = self.inode[ino];
    require(tx.origin == inode.owner, 'EACCES');
    if (flags & Constants.O_DIRECTORY() > 0) {
      require(inode.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
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
        inode.owner = tx.origin;
        inode.fileType = FileSystem.FileType.Regular;
        inode.lastModified = now;
        inode.links = 1;
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
    require(inode.fileType == FileSystem.FileType.Regular, 'EPERM');
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
    inode.lastModified = now;
  }

  function truncate(Disk storage self, uint ino, bytes calldata key, uint len) external onlyOwner(self) {
    Inode storage inode = self.inode[ino];
    require(inode.fileType == FileSystem.FileType.Regular, 'EPERM');
    uint inoExtent = inode.data[key];
    if (inoExtent == 0) {
      require(len == 0, 'EINVAL');
      return;
    }
    self.inodeExtent[inoExtent].extent.length = len;
    inode.lastModified = now;
  }

  function clear(Disk storage self, uint ino, bytes calldata key) external onlyOwner(self) {
    Inode storage inode = self.inode[ino];
    require(inode.fileType == FileSystem.FileType.Regular, 'EPERM');
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
    inode.lastModified = now;
  }

  function stat(Disk storage self, bytes calldata path, uint curdir) external view onlyOwner(self) returns (FileSystem.FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint size, uint lastModified) {
    ResolvedPath memory res = pathToInode2(self, path, curdir, 1);
    require(res.ino > 0, 'ENOENT');
    if (res.dirIno == 0) res.dirIno = res.ino;
    checkOpen(self, res.dirIno, 0);
    return _fstat(self, res.ino);
  }

  function fstat(Disk storage self, uint ino) external view onlyOwner(self) returns (FileSystem.FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint size, uint lastModified) {
    return _fstat(self, ino);
  }

  function _fstat(Disk storage self, uint ino) private view returns (FileSystem.FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint size, uint lastModified) {
    Inode storage inode = self.inode[ino];
    fileType = inode.fileType;
    permissions = inode.permissions;
    ino_ = ino;
    device = address(this);
    links = inode.links;
    owner = inode.owner;
    entries = inode.keys.length;
    uint inoExtent = inode.data[''];
    if (inoExtent > 0) {
      size = self.inodeExtent[inoExtent].extent.length;
    }
    lastModified = inode.lastModified;
  }

  function mkdir(Disk storage self, bytes calldata path, uint curdir) external onlyOwner(self) {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(self, path, curdir, 1);
    require(ino == 0, 'EEXIST');
    ino = allocInode(self);
    Inode storage inode = self.inode[ino];
    inode.owner = tx.origin;
    inode.fileType = FileSystem.FileType.Directory;
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
    require(inode.fileType == FileSystem.FileType.Directory, 'ENOTDIR');
    require(inode.keys.length == 2, 'ENOTEMPTY');
    removeFromInode(self, dirIno, key);
    if (--inode.refCnt == 0) freeInode(self, ino);
  }
}
