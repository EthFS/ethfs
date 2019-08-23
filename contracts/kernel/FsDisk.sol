pragma solidity >= 0.5.8;

import './FsLib.sol';
import './FsLib1.sol';

contract FsDisk is FileSystem {
  using FsLib for FsLib.Disk;
  using FsLib1 for FsLib.Disk;
  FsLib.Disk m_disk;

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

  function truncate(uint ino, bytes calldata key, uint len) external {
    m_disk.truncate(ino, key, len);
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

  function symlink(bytes calldata source, bytes calldata target, uint curdir) external {
    m_disk.symlink(source, target, curdir);
  }

  function readlink(bytes calldata path, uint curdir) external view returns (bytes memory) {
    return m_disk.readlink(path, curdir);
  }

  function move(bytes calldata source, bytes calldata target, uint curdir) external {
    m_disk.move(source, target, curdir);
  }

  function copy(bytes calldata source, bytes calldata target, uint curdir) external {
    m_disk.copy(source, target, curdir);
  }

  function chown(bytes calldata path, address owner, address group, uint curdir) external {
    m_disk.chown(path, owner, group, curdir);
  }

  function chmod(bytes calldata path, uint16 mode, uint curdir) external {
    m_disk.chmod(path, mode, curdir);
  }

  function mkdir(bytes calldata path, uint curdir) external {
    m_disk.mkdir(path, curdir);
  }

  function rmdir(bytes calldata path, uint curdir) external {
    m_disk.rmdir(path, curdir);
  }

  function stat(bytes calldata path, uint curdir) external view returns (FileType fileType, uint16 mode, uint ino_, uint links, address owner, address group, uint entries, uint size, uint lastModified) {
    return m_disk.stat(path, curdir);
  }

  function fstat(uint ino) external view returns (FileType fileType, uint16 mode, uint ino_, uint links, address owner, address group, uint entries, uint size, uint lastModified) {
    return m_disk.fstat(ino);
  }
}
