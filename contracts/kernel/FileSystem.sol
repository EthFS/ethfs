pragma solidity >= 0.5.8;

import '../interface/FileSystem.sol';

contract FileSystemImpl is FileSystem {
  uint constant O_RDONLY  = 0x0000;
  uint constant O_WRONLY  = 0x0001;
  uint constant O_RDWR    = 0x0002;
  uint constant O_ACCMODE = 0x0003;

  uint constant O_CREAT = 0x0100;
  uint constant O_EXCL  = 0x0200;

  uint constant O_DIRECTORY = 0x00200000;

  enum FileType { None, Contract, Data, Directory }

  struct Inode {
    address owner;
    FileType fileType;
    uint permissions;
    uint lastModified;
    uint links;
    uint entries;
    bytes32[] keys;
    mapping(bytes32 => InodeData) data;
  }

  struct InodeData {
    uint index;
    bytes32 value;
  }

  address m_owner;
  Inode[] m_inode;

  modifier onlyOwner {
    require(msg.sender == m_owner, 'EPERM');
    _;
  }

  constructor() public {
    // Set up root inode
    uint ino = 1;
    m_inode.length = ino+1;
    m_inode[ino].owner = tx.origin;
    m_inode[ino].fileType = FileType.Directory;
    writeToInode(ino, '.', bytes32(ino));
    writeToInode(ino, '..', bytes32(ino));
  }

  function mount() external {
    require(m_owner == address(0), 'EPERM');
    m_owner = msg.sender;
  }

  function unmount() external onlyOwner {
    m_owner = address(0);
  }

  function pathToInode(bytes memory path, uint curdir, bool allowNonExistDir) private view returns (uint ino, uint dirIno, bytes32 key) {
    if (curdir == 0) curdir = 1;
    bool fromRoot = path.length > 0 && path[0] == '/';
    ino = fromRoot ? 1 : curdir;
    uint j;
    for (uint i = 0; i <= path.length; i++) {
      while (i < path.length && path[i] != '/') i++;
      if (i == j) {
        j++;
        continue;
      }
      require(ino > 0, 'ENOENT');
      Inode storage inode = m_inode[ino];
      require(inode.fileType == FileType.Directory, 'ENOTDIR');
      require(i-j <= 32, 'ENAMETOOLONG');
      key = 0;
      for (uint k = 0; j < i; k += 8) {
        bytes32 x = path[j++];
        assembly { x := shr(k, x) }
        key |= x;
      }
      j++;
      dirIno = ino;
      ino = uint(inode.data[key].value);
    }
    if (ino == 0) {
      require(allowNonExistDir || path[path.length-1] != '/', 'ENOENT');
    } else if (m_inode[ino].fileType != FileType.Directory) {
      require(path[path.length-1] != '/', 'ENOTDIR');
    }
    if (key == '.' || key == '..') {
      dirIno = uint(m_inode[ino].data['..'].value);
      Inode storage inode = m_inode[dirIno];
      for (uint i;;) {
        bytes32 key2 = inode.keys[i++];
        if (key2 > 0 && uint(inode.data[key2].value) == ino) {
          key = key2;
          break;
        }
      }
    }
  }

  function writeToInode(uint ino, bytes32 key, bytes32 value) private {
    Inode storage inode = m_inode[ino];
    InodeData storage data = inode.data[key];
    if (data.index == 0) {
      inode.entries++;
      inode.keys.push(key);
      data.index = inode.keys.length;  // index+1
    }
    data.value = value;
    inode.lastModified = now;
  }

  function removeFromInode(uint ino, bytes32 key) private {
    Inode storage inode = m_inode[ino];
    inode.entries--;
    delete inode.keys[inode.data[key].index-1];
    delete inode.data[key];
    inode.lastModified = now;
  }

  function checkOpen(uint ino, uint flags) private view {
    require(ino > 0, 'ENOENT');
    Inode storage inode = m_inode[ino];
    require(tx.origin == inode.owner, 'EACCES');
    if (flags & O_DIRECTORY > 0) {
      require(inode.fileType == FileType.Directory, 'ENOTDIR');
    }
  }

  function open(bytes calldata path, uint curdir, uint flags) external onlyOwner returns (uint) {
    (uint ino, uint dirIno, bytes32 key) = pathToInode(path, curdir, false);
    if (flags & O_CREAT > 0) {
      if (ino > 0) {
        require(flags & O_EXCL == 0, 'EEXIST');
      } else {
        ino = m_inode.length++;
        Inode storage inode = m_inode[ino];
        inode.owner = tx.origin;
        inode.fileType = FileType.Data;
        inode.lastModified = now;
        inode.links = 1;
        writeToInode(dirIno, key, bytes32(ino));
      }
    }
    checkOpen(ino, flags);
    return ino;
  }

  function openOnly(bytes calldata path, uint curdir, uint flags) external view onlyOwner returns (uint ino) {
    (ino,,) = pathToInode(path, curdir, false);
    checkOpen(ino, flags);
  }

  function read(uint ino, bytes32 key) external view onlyOwner returns (bytes32) {
    InodeData storage data = m_inode[ino].data[key];
    require(data.index > 0, 'EINVAL');
    return data.value;
  }

  function write(uint ino, bytes32 key, bytes32 data) external onlyOwner {
    writeToInode(ino, key, data);
  }

  function clear(uint ino, bytes32 key) external onlyOwner {
    InodeData storage data = m_inode[ino].data[key];
    require(data.index > 0, 'EINVAL');
    removeFromInode(ino, key);
  }

  function link(bytes calldata source, bytes calldata target, uint curdir) external onlyOwner {
    (uint ino,, bytes32 key) = pathToInode(source, curdir, false);
    require(ino > 0, 'ENOENT');
    Inode storage inode = m_inode[ino];
    require(inode.fileType != FileType.Directory, 'EISDIR');
    (uint ino2, uint dirIno, bytes32 key2) = pathToInode(target, curdir, false);
    if (ino2 > 0) {
      require(m_inode[ino2].fileType == FileType.Directory, 'EEXIST');
      dirIno = ino2;
    } else {
      key = key2;
    }
    InodeData storage data = m_inode[dirIno].data[key];
    require(data.index == 0, 'EEXIST');
    writeToInode(dirIno, key, bytes32(ino));
    inode.links++;
  }

  function unlink(bytes calldata path, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes32 key) = pathToInode(path, curdir, false);
    require(ino > 0, 'ENOENT');
    Inode storage inode = m_inode[ino];
    require(inode.fileType != FileType.Directory, 'EISDIR');
    removeFromInode(dirIno, key);
    if (--inode.links == 0) delete m_inode[ino];
  }

  function move(bytes calldata source, bytes calldata target, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes32 key) = pathToInode(source, curdir, false);
    require(ino > 0, 'ENOENT');
    bool sourceIsDir = m_inode[ino].fileType == FileType.Directory;
    (uint ino2, uint dirIno2, bytes32 key2) = pathToInode(target, curdir, true);
    if (ino == ino2) return;
    if (ino2 > 0) {
      Inode storage inode = m_inode[ino2];
      if (inode.fileType == FileType.Directory) {
        if (ino2 == dirIno) return;
        dirIno2 = ino2;
        key2 = key;
      } else {
        require(!sourceIsDir, 'ENOTDIR');
        removeFromInode(dirIno2, key2);
        if (--inode.links == 0) delete m_inode[ino2];
      }
    } else if (!sourceIsDir) {
      require(target[target.length-1] != '/', 'ENOENT');
    }
    if (sourceIsDir) {
      uint ino3 = dirIno2;
      while (true) {
        require(ino3 != ino, 'EINVAL');
        if (ino3 == 1) break;
        ino3 = uint(m_inode[ino3].data['..'].value);
      }
      writeToInode(ino, '..', bytes32(dirIno2));
    }
    removeFromInode(dirIno, key);
    writeToInode(dirIno2, key2, bytes32(ino));
  }

  function install(address source, bytes calldata target, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes32 key) = pathToInode(target, curdir, false);
    require(ino == 0, 'EEXIST');
    ino = m_inode.length++;
    Inode storage inode = m_inode[ino];
    inode.owner = source;
    inode.fileType = FileType.Contract;
    inode.lastModified = now;
    inode.links = 1;
    writeToInode(dirIno, key, bytes32(ino));
  }

  function mkdir(bytes calldata path, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes32 key) = pathToInode(path, curdir, true);
    require(ino == 0, 'EEXIST');
    ino = m_inode.length++;
    Inode storage inode = m_inode[ino];
    inode.owner = tx.origin;
    inode.fileType = FileType.Directory;
    writeToInode(dirIno, key, bytes32(ino));
    writeToInode(ino, '.', bytes32(ino));
    writeToInode(ino, '..', bytes32(dirIno));
  }

  function rmdir(bytes calldata path, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes32 key) = pathToInode(path, curdir, false);
    require(ino > 0, 'ENOENT');
    require(ino != curdir, 'EINVAL');
    Inode storage inode = m_inode[ino];
    require(inode.fileType == FileType.Directory, 'ENOTDIR');
    require(inode.entries == 2, 'ENOTEMPTY');
    removeFromInode(dirIno, key);
    delete m_inode[ino];
  }

  function list(uint ino) external view onlyOwner returns (bytes32[] memory result) {
    Inode storage inode = m_inode[ino];
    result = new bytes32[](inode.entries);
    if (result.length > 0) {
      uint j;
      for (uint i; i < inode.keys.length; i++) {
        bytes32 key = inode.keys[i];
        if (key > 0) {
          result[j++] = key;
          if (j == result.length) break;
        }
      }
    }
  }

  function readContract(bytes calldata path, uint curdir) external view onlyOwner returns (address) {
    (uint ino,,) = pathToInode(path, curdir, false);
    require(ino > 0, 'ENOENT');
    Inode storage inode = m_inode[ino];
    require(inode.fileType != FileType.Directory, 'EISDIR');
    require(inode.fileType == FileType.Contract, 'ENOEXEC');
    return inode.owner;
  }
}
