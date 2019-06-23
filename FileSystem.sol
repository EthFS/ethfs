pragma solidity >= 0.5.9;

import "./interface/FileSystem.sol";

contract FileSystemImpl is FileSystem {
  uint constant O_RDONLY  = 0x0000;
  uint constant O_WRONLY  = 0x0001;
  uint constant O_RDWR    = 0x0002;
  uint constant O_ACCMODE = 0x0003;

  uint constant O_CREAT = 0x0200;
  uint constant O_EXCL  = 0x0800;

  enum FileType { Contract, Data, Directory }

  struct Inode {
    address owner;
    FileType fileType;
    uint permissions;
    uint lastModified;
    uint links;
    bytes32[] keys;
    mapping(bytes32 => bytes32) data;
  }

  address m_owner;
  Inode[] m_inode;

  modifier onlyOwner {
    require(msg.sender == m_owner, "EPERM");
    _;
  }

  constructor() public {
    // Set up root inode
    m_inode.length = 2;
    m_inode[1].owner = msg.sender;
    m_inode[1].fileType = FileType.Directory;
    m_inode[1].lastModified = now;
  }

  function mount() external {
    require(m_owner == address(0), "EPERM");
    m_owner = msg.sender;
  }

  function unmount() external onlyOwner {
    m_owner = address(0);
  }

  function pathToInode(bytes32[] memory path, bool dirOnly) private view returns(uint) {
    uint inode = 1;
    for (uint i = 0; i < path.length; i++) {
      require(inode > 0, "ENOENT");
      require(m_inode[inode].fileType == FileType.Directory, "ENOTDIR");
      if (dirOnly && i == path.length-1) break;
      inode = uint(m_inode[inode].data[path[i]]);
    }
    return inode;
  }

  function create(address owner, bytes32[] memory path) private returns(uint) {
    uint dirInode = pathToInode(path, true);
    uint inode = m_inode.length++;
    m_inode[inode].owner = owner;
    m_inode[inode].fileType = FileType.Data;
    m_inode[inode].lastModified = now;
    m_inode[inode].links = 1;
    m_inode[dirInode].data[path[path.length-1]] = bytes32(inode);
    return inode;
  }

  function open(address sender, bytes32[] calldata path, uint flags) external onlyOwner returns(uint) {
    uint inode = pathToInode(path, false);
    if (flags & O_CREAT > 0) {
      if (flags & O_EXCL > 0) require(inode == 0, "EEXIST");
      if (inode == 0) inode = create(sender, path);
    }
    require(inode > 0, "ENOENT");
    require(sender == m_inode[inode].owner, "EACCES");
    return inode;
  }

  function read(uint inode, bytes32 key) external view onlyOwner returns(bytes32) {
    return m_inode[inode].data[key];
  }

  function write(uint inode, bytes32 key, bytes32 data) external onlyOwner {
    m_inode[inode].data[key] = data;
    m_inode[inode].lastModified = now;
  }

  function link(bytes32[] calldata source, bytes32[] calldata target) external onlyOwner {
    uint inode = pathToInode(source, false);
    require(inode > 0, "ENOENT");
    uint dirInode = pathToInode(target, true);
    m_inode[dirInode].data[target[target.length-1]] = bytes32(inode);
    m_inode[inode].links++;
  }

  function unlink(bytes32[] calldata path) external onlyOwner {
    uint dirInode = pathToInode(path, true);
    uint inode = uint(m_inode[dirInode].data[path[path.length-1]]);
    require(inode > 0, "ENOENT");
    delete m_inode[dirInode].data[path[path.length-1]];
    uint links = --m_inode[inode].links;
    if (links == 0) {
      delete m_inode[inode];
    }
  }
}
