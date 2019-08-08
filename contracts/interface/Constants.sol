pragma solidity >= 0.5.8;

library Constants {
  uint public constant _O_RDONLY  = 0x0000;
  uint public constant _O_WRONLY  = 0x0001;
  uint public constant _O_RDWR    = 0x0002;
  uint public constant _O_ACCMODE = 0x0003;

  uint public constant _O_CREAT = 0x0100;
  uint public constant _O_EXCL  = 0x0200;

  uint public constant _O_DIRECTORY = 0x00200000;

  function O_RDONLY()  internal pure returns (uint) { return _O_RDONLY; }
  function O_WRONLY()  internal pure returns (uint) { return _O_WRONLY; }
  function O_RDWR()    internal pure returns (uint) { return _O_RDWR; }
  function O_ACCMODE() internal pure returns (uint) { return _O_ACCMODE; }

  function O_CREAT()   internal pure returns (uint) { return _O_CREAT; }
  function O_EXCL()    internal pure returns (uint) { return _O_EXCL; }

  function O_DIRECTORY() internal pure returns (uint) { return _O_DIRECTORY; }
}
