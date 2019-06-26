pragma solidity >= 0.5.8;

import "./interface/FileSystem.sol";

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
    bytes32 value;
    uint index;
  }

  address m_owner;
  Inode[] m_inode;

  modifier onlyOwner {
    require(msg.sender == m_owner, "EPERM");
    _;
  }

  constructor() public {
    // Set up root inode
    uint ino = 1;
    m_inode.length = ino+1;
    m_inode[ino].owner = tx.origin;
    m_inode[ino].fileType = FileType.Directory;
    writeToInode(ino, ".", bytes32(ino));
    writeToInode(ino, "..", bytes32(ino));
  }

  function mount() external {
    require(m_owner == address(0), "EPERM");
    m_owner = msg.sender;
  }

  function unmount() external onlyOwner {
    m_owner = address(0);
  }

  function pathToInode(bytes32[] memory path, uint curdir, bool dirOnly) private view returns (uint) {
    if (curdir == 0) curdir = 1;
    bool fromRoot = path.length > 0 && path[0] == 0;
    uint ino = fromRoot ? 1 : curdir;
    for (uint i = 0; i < path.length; i++) {
      require(ino > 0, "ENOENT");
      Inode storage inode = m_inode[ino];
      require(inode.fileType == FileType.Directory, "ENOTDIR");
      if (path[i] == 0) continue;
      if (dirOnly && i == path.length-1) break;
      ino = uint(inode.data[path[i]].value);
    }
    return ino;
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

  function creat(bytes32[] memory path, uint curdir) private returns (uint) {
    uint dirIno = pathToInode(path, curdir, true);
    uint ino = m_inode.length++;
    Inode storage inode = m_inode[ino];
    inode.owner = tx.origin;
    inode.fileType = FileType.Data;
    inode.lastModified = now;
    inode.links = 1;
    writeToInode(dirIno, path[path.length-1], bytes32(ino));
    return ino;
  }

  function checkOpen(uint ino, uint flags) private view {
    require(ino > 0, "ENOENT");
    Inode storage inode = m_inode[ino];
    require(tx.origin == inode.owner, "EACCES");
    if (flags & O_DIRECTORY > 0) {
      require(inode.fileType == FileType.Directory, "ENOTDIR");
    }
  }

  function open(bytes32[] calldata path, uint curdir, uint flags) external onlyOwner returns (uint) {
    uint ino = pathToInode(path, curdir, false);
    if (flags & O_CREAT > 0) {
      if (flags & O_EXCL > 0) require(ino == 0, "EEXIST");
      if (ino == 0) ino = creat(path, curdir);
    }
    checkOpen(ino, flags);
    return ino;
  }

  function openOnly(bytes32[] calldata path, uint curdir, uint flags) external view onlyOwner returns (uint) {
    uint ino = pathToInode(path, curdir, false);
    checkOpen(ino, flags);
    return ino;
  }

  function read(uint ino, bytes32 key) external view onlyOwner returns (bytes32) {
    InodeData storage data = m_inode[ino].data[key];
    require(data.index > 0, "EINVAL");
    return data.value;
  }

  function write(uint ino, bytes32 key, bytes32 data) external onlyOwner {
    writeToInode(ino, key, data);
  }

  function clear(uint ino, bytes32 key) external onlyOwner {
    InodeData storage data = m_inode[ino].data[key];
    require(data.index > 0, "EINVAL");
    removeFromInode(ino, key);
  }

  function link(bytes32[] calldata source, bytes32[] calldata target, uint curdir) external onlyOwner {
    uint ino = pathToInode(source, curdir, false);
    require(ino > 0, "ENOENT");
    uint dirIno = pathToInode(target, curdir, true);
    bytes32 key = target[target.length-1];
    if (key == 0) key = source[source.length-1];
    InodeData storage data = m_inode[dirIno].data[key];
    require(data.index == 0, "EEXIST");
    writeToInode(dirIno, key, bytes32(ino));
    m_inode[ino].links++;
  }

  function unlink(bytes32[] calldata path, uint curdir) external onlyOwner {
    uint dirIno = pathToInode(path, curdir, true);
    bytes32 key = path[path.length-1];
    require(key != 0, "EISDIR");
    InodeData storage data = m_inode[dirIno].data[key];
    require(data.index > 0, "ENOENT");
    uint ino = uint(data.value);
    Inode storage inode = m_inode[ino];
    require(inode.fileType != FileType.Directory, "EISDIR");
    removeFromInode(dirIno, key);
    if (--inode.links == 0) delete m_inode[ino];
  }

  function linkContract(address source, bytes32[] calldata target, uint curdir) external onlyOwner {
    uint dirIno = pathToInode(target, curdir, true);
    bytes32 key = target[target.length-1];
    require(key != 0, "EISDIR");
    InodeData storage data = m_inode[dirIno].data[key];
    require(data.index == 0, "EEXIST");
    uint ino = m_inode.length++;
    Inode storage inode = m_inode[ino];
    inode.owner = source;
    inode.fileType = FileType.Contract;
    inode.lastModified = now;
    inode.links = 1;
    writeToInode(dirIno, key, bytes32(ino));
  }

  function mkdir(bytes32[] calldata path, uint curdir) external onlyOwner {
    uint dirIno = pathToInode(path, curdir, true);
    bytes32 key = path[path.length-1];
    require(key != 0, "EEXIST");
    InodeData storage data = m_inode[dirIno].data[key];
    require(data.index == 0, "EEXIST");
    uint ino = m_inode.length++;
    Inode storage inode = m_inode[ino];
    inode.owner = tx.origin;
    inode.fileType = FileType.Directory;
    writeToInode(dirIno, key, bytes32(ino));
    writeToInode(ino, ".", bytes32(ino));
    writeToInode(ino, "..", bytes32(dirIno));
  }

  function rmdir(bytes32[] calldata path, uint curdir) external onlyOwner {
    uint dirIno = pathToInode(path, curdir, true);
    bytes32 key = path[path.length-1];
    InodeData storage data = m_inode[dirIno].data[key];
    require(data.index > 0, "ENOENT");
    uint ino = uint(data.value);
    Inode storage inode = m_inode[ino];
    require(inode.fileType == FileType.Directory, "ENOTDIR");
    require(inode.entries == 2, "ENOTEMPTY");
    removeFromInode(dirIno, key);
    delete m_inode[ino];
  }

  function list(uint ino) external view onlyOwner returns (bytes32[] memory) {
    Inode storage inode = m_inode[ino];
    bytes32[] memory result = new bytes32[](inode.entries);
    if (result.length > 0) {
      bytes32[] storage keys = inode.keys;
      uint j = 0;
      for (uint i = 0; i < keys.length; i++) {
        bytes32 key = keys[i];
        if (inode.data[key].index == i+1) {
          result[j++] = key;
          if (j == result.length) break;
        }
      }
    }
    return result;
  }

  function readContract(bytes32[] calldata path, uint curdir) external view onlyOwner returns (address) {
    uint ino = pathToInode(path, curdir, false);
    require(ino > 0, "ENOENT");
    Inode storage inode = m_inode[ino];
    require(inode.fileType == FileType.Contract, "ENOEXEC");
    return inode.owner;
  }
}
