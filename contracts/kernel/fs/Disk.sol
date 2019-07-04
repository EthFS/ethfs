pragma solidity >= 0.5.8;

import './Lib0.sol';
import './Lib1.sol';
import './Lib2.sol';

contract FileSystemDisk is FileSystem {
  using FileSystemLib for FileSystemLib.Disk;
  using FileSystemLib1 for FileSystemLib.Disk;
  using FileSystemLib2 for FileSystemLib.Disk;
  FileSystemLib.Disk m_disk;

  constructor() public {
    m_disk.init();
  }

  function mount() external {
    m_disk.mount();
  }

  function unmount() external {
    m_disk.unmount();
  }

  function dirInodeToPath(uint ino) external view returns (bytes memory) {
    return m_disk.dirInodeToPath(ino);
  }

  function open(bytes calldata path, uint curdir, uint flags) external returns (uint) {
    return m_disk.open(path, curdir, flags);
  }

  function openOnly(bytes calldata path, uint curdir, uint flags) external view returns (uint) {
    return m_disk.openOnly(path, curdir, flags);
  }

  function close(uint ino) external {
    m_disk.close(ino);
  }

  function readkey(uint ino, uint index) external view returns (bytes memory) {
    return m_disk.readkey(ino, index);
  }

  function read(uint ino, bytes calldata key) external view returns (bytes memory) {
    return m_disk.read(ino, key);
  }

  function write(uint ino, bytes calldata key, bytes calldata value) external {
    m_disk.write(ino, key, value);
  }

  function clear(uint ino, bytes calldata key) external {
    m_disk.clear(ino, key);
  }

  function link(bytes calldata source, bytes calldata target, uint curdir) external {
    m_disk.link(source, target, curdir);
  }

  function unlink(bytes calldata path, uint curdir) external {
    m_disk.unlink(path, curdir);
  }

  function move(bytes calldata source, bytes calldata target, uint curdir) external {
    m_disk.move(source, target, curdir);
  }

  function copy(bytes calldata source, bytes calldata target, uint curdir) external {
    m_disk.copy(source, target, curdir);
  }

  function install(address source, bytes calldata target, uint curdir) external {
    m_disk.install(source, target, curdir);
  }

  function mkdir(bytes calldata path, uint curdir) external {
    m_disk.mkdir(path, curdir);
  }

  function rmdir(bytes calldata path, uint curdir) external {
    m_disk.rmdir(path, curdir);
  }

  function stat(bytes calldata path, uint curdir) external view returns (FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint lastModified) {
    return m_disk.stat(path, curdir);
  }

  function fstat(uint ino) external view returns (FileType fileType, uint permissions, uint ino_, address device, uint links, address owner, uint entries, uint lastModified) {
    return m_disk.fstat(ino);
  }

  function readContract(bytes calldata path, uint curdir) external view returns (address) {
    return m_disk.readContract(path, curdir);
  }
}
