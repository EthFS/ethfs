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

  struct Inode {
    address owner;
    FileType fileType;
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

  address m_owner;
  Inode[] m_inode;
  InodeData[] m_inodeData;
  uint[] m_freeIno;
  uint[] m_freeInoData;

  modifier onlyOwner {
    require(msg.sender == m_owner, 'EPERM');
    _;
  }

  constructor() public {
    // Set up root inode
    uint ino = 1;
    m_inode.length = ino+1;
    m_inodeData.length = 1;
    m_inode[ino].owner = tx.origin;
    m_inode[ino].fileType = FileType.Directory;
    writeToInode(ino, '.', ino);
    writeToInode(ino, '..', ino);
  }

  function mount() external {
    require(m_owner == address(0), 'EPERM');
    m_owner = msg.sender;
  }

  function unmount() external onlyOwner {
    m_owner = address(0);
  }

  function pathToInode(bytes memory path, uint curdir, bool allowNonExistDir) private view returns (uint ino, uint dirIno, bytes memory key) {
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
      Inode storage inode = m_inode[ino];
      require(inode.fileType == FileType.Directory, 'ENOTDIR');
      require(tx.origin == inode.owner, 'EACCES');
      key = new bytes(i-j);
      for (uint k; j < i;) key[k++] = path[j++];
      j++;
      dirIno = ino;
      ino = m_inodeData[inode.data[key]].value;
    }
    if (ino == 0) {
      require(allowNonExistDir || path[path.length-1] != '/', 'ENOENT');
    } else if (m_inode[ino].fileType != FileType.Directory) {
      require(path[path.length-1] != '/', 'ENOTDIR');
    }
    if (key.length == 1 && key[0] == '.' ||
        key.length == 2 && key[0] == '.' && key[1] == '.') {
      dirIno = m_inodeData[m_inode[ino].data['..']].value;
      Inode storage inode = m_inode[dirIno];
      for (uint i;;) {
        bytes storage key2 = inode.keys[i++];
        if (m_inodeData[inode.data[key2]].value == ino) {
          key = key2;
          break;
        }
      }
    }
  }

  function dirInodeToPath(uint ino_) external view onlyOwner returns (bytes memory path) {
    uint ino = ino_;
    Inode storage inode = m_inode[ino];
    require(inode.fileType == FileType.Directory, 'ENOTDIR');
    while (ino != 1) {
      uint dirIno = m_inodeData[inode.data['..']].value;
      inode = m_inode[dirIno];
      require(tx.origin == inode.owner, 'EACCES');
      for (uint i;;) {
        bytes storage key = inode.keys[i++];
        if (m_inodeData[inode.data[key]].value != ino) continue;
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

  function allocInode() private returns(uint ino) {
    if (m_freeIno.length > 0) {
      ino = m_freeIno[m_freeIno.length-1];
      m_freeIno.pop();
    } else {
      ino = m_inode.length++;
    }
  }

  function freeInode(uint ino) private {
    Inode storage inode = m_inode[ino];
    for (uint i; i < inode.keys.length;) {
      bytes storage key = inode.keys[i++];
      m_freeInoData.push(inode.data[key]);
      delete inode.data[key];
    }
    m_freeIno.push(ino);
  }

  function allocInodeData() private returns(uint inoData) {
    if (m_freeInoData.length > 0) {
      inoData = m_freeInoData[m_freeInoData.length-1];
      m_freeInoData.pop();
    } else {
      inoData = m_inodeData.length++;
    }
  }

  function writeToInode(uint ino, bytes memory key, uint value) private {
    Inode storage inode = m_inode[ino];
    if (inode.data[key] == 0) {
      inode.data[key] = allocInodeData();
      InodeData storage data = m_inodeData[inode.data[key]];
      inode.keys.push(key);
      data.index = inode.keys.length;  // index+1
      data.value = value;
    } else {
      m_inodeData[inode.data[key]].value = value;
    }
    inode.lastModified = now;
  }

  function removeFromInode(uint ino, bytes memory key) private {
    Inode storage inode = m_inode[ino];
    bytes[] storage keys = inode.keys;
    uint inoData = inode.data[key];
    uint index = m_inodeData[inoData].index-1;
    if (index < keys.length-1) {
      bytes storage key2 = keys[keys.length-1];
      keys[index] = key2;
      m_inodeData[inode.data[key2]].index = index+1;
    }
    keys.pop();
    m_freeInoData.push(inoData);
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
    (uint ino, uint dirIno, bytes memory key) = pathToInode(path, curdir, false);
    if (flags & O_CREAT > 0) {
      if (ino > 0) {
        require(flags & O_EXCL == 0, 'EEXIST');
      } else {
        ino = allocInode();
        Inode storage inode = m_inode[ino];
        inode.owner = tx.origin;
        inode.fileType = FileType.Data;
        inode.lastModified = now;
        inode.links = 1;
        writeToInode(dirIno, key, ino);
      }
    }
    checkOpen(ino, flags);
    return ino;
  }

  function openOnly(bytes calldata path, uint curdir, uint flags) external view onlyOwner returns (uint ino) {
    (ino,,) = pathToInode(path, curdir, false);
    checkOpen(ino, flags);
  }

  function readkey(uint ino, uint index) external view onlyOwner returns (bytes memory) {
    return m_inode[ino].keys[index];
  }

  function read(uint ino, bytes calldata key) external view onlyOwner returns (bytes memory) {
    uint inoData = m_inode[ino].data[key];
    require(inoData > 0, 'EINVAL');
    return m_inodeData[inoData].extent;
  }

  function write(uint ino, bytes calldata key, bytes calldata value) external onlyOwner {
    Inode storage inode = m_inode[ino];
    require(inode.fileType == FileType.Data, 'EPERM');
    if (inode.data[key] == 0) {
      inode.data[key] = allocInodeData();
      InodeData storage data = m_inodeData[inode.data[key]];
      inode.keys.push(key);
      data.index = inode.keys.length;  // index+1
      data.extent = value;
    } else {
      m_inodeData[inode.data[key]].extent = value;
    }
    inode.lastModified = now;
  }

  function clear(uint ino, bytes calldata key) external onlyOwner {
    Inode storage inode = m_inode[ino];
    require(inode.fileType == FileType.Data, 'EPERM');
    require(inode.data[key] > 0, 'EINVAL');
    removeFromInode(ino, key);
  }

  function link(bytes calldata source, bytes calldata target, uint curdir) external onlyOwner {
    (uint ino,, bytes memory key) = pathToInode(source, curdir, false);
    require(ino > 0, 'ENOENT');
    Inode storage inode = m_inode[ino];
    require(inode.fileType != FileType.Directory, 'EISDIR');
    (uint ino2, uint dirIno, bytes memory key2) = pathToInode(target, curdir, false);
    if (ino2 > 0) {
      require(m_inode[ino2].fileType == FileType.Directory, 'EEXIST');
      dirIno = ino2;
    } else {
      key = key2;
    }
    require(m_inode[dirIno].data[key] == 0, 'EEXIST');
    writeToInode(dirIno, key, ino);
    inode.links++;
  }

  function unlink(bytes calldata path, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(path, curdir, false);
    require(ino > 0, 'ENOENT');
    Inode storage inode = m_inode[ino];
    require(inode.fileType != FileType.Directory, 'EISDIR');
    removeFromInode(dirIno, key);
    if (--inode.links == 0) freeInode(ino);
  }

  function move(bytes calldata source, bytes calldata target, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(source, curdir, false);
    require(ino > 0, 'ENOENT');
    bool sourceIsDir = m_inode[ino].fileType == FileType.Directory;
    (uint ino2, uint dirIno2, bytes memory key2) = pathToInode(target, curdir, true);
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
        if (--inode.links == 0) freeInode(ino2);
      }
    } else if (!sourceIsDir) {
      require(target[target.length-1] != '/', 'ENOENT');
    }
    if (sourceIsDir) {
      ino2 = dirIno2;
      while (true) {
        require(ino2 != ino, 'EINVAL');
        if (ino2 == 1) break;
        ino2 = m_inodeData[m_inode[ino2].data['..']].value;
      }
      writeToInode(ino, '..', dirIno2);
    }
    removeFromInode(dirIno, key);
    writeToInode(dirIno2, key2, ino);
  }

  function copy(bytes calldata source, bytes calldata target, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(source, curdir, false);
    require(ino > 0, 'ENOENT');
    Inode storage inode = m_inode[ino];
    bool sourceIsDir = inode.fileType == FileType.Directory;
    (uint ino2, uint dirIno2, bytes memory key2) = pathToInode(target, curdir, true);
    if (ino == ino2) return;
    uint newIno;
    if (ino2 > 0) {
      Inode storage inode2 = m_inode[ino2];
      if (inode2.fileType == FileType.Directory) {
        if (ino2 == dirIno) return;
        dirIno2 = ino2;
        key2 = key;
      } else {
        require(!sourceIsDir, 'ENOTDIR');
        if (--inode2.links == 0) newIno = ino2;
      }
    } else if (!sourceIsDir) {
      require(target[target.length-1] != '/', 'ENOENT');
    }
    if (sourceIsDir) {
      ino2 = dirIno2;
      while (true) {
        require(ino2 != ino, 'EINVAL');
        if (ino2 == 1) break;
        ino2 = m_inodeData[m_inode[ino2].data['..']].value;
      }
    }
    if (newIno == 0) {
      newIno = allocInode();
      writeToInode(dirIno2, key2, newIno);
    }
    copyInode(inode, newIno, dirIno2);
  }

  function copyInode(Inode storage inode, uint ino, uint dirIno) private {
    bool sourceIsDir = inode.fileType == FileType.Directory;
    Inode storage inode2 = m_inode[ino];
    inode2.owner = inode.owner;
    inode2.fileType = inode.fileType;
    inode2.permissions = inode.permissions;
    uint i;
    if (sourceIsDir) {
      i = 2;
      writeToInode(ino, '.', ino);
      writeToInode(ino, '..', dirIno);
    } else {
      inode2.links = 1;
      while (i < inode2.keys.length) {
        bytes storage key = inode2.keys[i++];
        m_freeInoData.push(inode2.data[key]);
        delete inode2.data[key];
      }
      i = 0;
    }
    inode2.lastModified = inode.lastModified;
    inode2.keys.length = inode.keys.length;
    for (; i < inode.keys.length; i++) {
      bytes storage key = inode.keys[i];
      inode2.keys[i] = key;
      inode2.data[key] = allocInodeData();
      InodeData storage data = m_inodeData[inode.data[key]];
      InodeData storage data2 = m_inodeData[inode2.data[key]];
      data2.index = data.index;
      if (sourceIsDir) {
        data2.value = allocInode();
        copyInode(m_inode[data.value], data2.value, ino);
      } else {
        data2.extent = data.extent;
      }
    }
  }

  function install(address source, bytes calldata target, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(target, curdir, false);
    require(ino == 0, 'EEXIST');
    ino = allocInode();
    Inode storage inode = m_inode[ino];
    inode.owner = source;
    inode.fileType = FileType.Contract;
    inode.lastModified = now;
    inode.links = 1;
    writeToInode(dirIno, key, ino);
  }

  function mkdir(bytes calldata path, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(path, curdir, true);
    require(ino == 0, 'EEXIST');
    ino = allocInode();
    Inode storage inode = m_inode[ino];
    inode.owner = tx.origin;
    inode.fileType = FileType.Directory;
    writeToInode(dirIno, key, ino);
    writeToInode(ino, '.', ino);
    writeToInode(ino, '..', dirIno);
  }

  function rmdir(bytes calldata path, uint curdir) external onlyOwner {
    (uint ino, uint dirIno, bytes memory key) = pathToInode(path, curdir, false);
    require(ino > 0, 'ENOENT');
    require(ino != curdir, 'EINVAL');
    Inode storage inode = m_inode[ino];
    require(inode.fileType == FileType.Directory, 'ENOTDIR');
    require(inode.keys.length == 2, 'ENOTEMPTY');
    removeFromInode(dirIno, key);
    freeInode(ino);
  }

  function stat(bytes calldata path, uint curdir) external view onlyOwner returns (FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint lastModified) {
    (uint ino, uint dirIno,) = pathToInode(path, curdir, false);
    require(ino > 0, 'ENOENT');
    if (dirIno == 0) dirIno = ino;
    checkOpen(dirIno, 0);
    return _fstat(ino);
  }

  function fstat(uint ino) external view onlyOwner returns (FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint lastModified) {
    return _fstat(ino);
  }

  function _fstat(uint ino) private view returns (FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint lastModified) {
    Inode storage inode = m_inode[ino];
    fileType = inode.fileType;
    permissions = inode.permissions;
    ino_ = ino;
    device = address(this);
    links = inode.links;
    owner = inode.owner;
    entries = inode.keys.length;
    lastModified = inode.lastModified;
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
