// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.8;

interface Group {
  function contains(address user) external view returns (bool);
}
