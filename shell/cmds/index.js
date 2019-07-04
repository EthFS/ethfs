const cat = require('./cat')
const chdir = require('./chdir')
const exec = require('./exec')
const install = require('./install')
const ln = require('./ln')
const ls = require('./ls')
const mkdir = require('./mkdir')
const pwd = require('./pwd')
const rm = require('./rm')
const rmdir = require('./rmdir')
const write = require('./write')

module.exports = {
  cat,
  cd: chdir,
  chdir,
  exec,
  install,
  ln,
  ls,
  mkdir,
  pwd,
  rm,
  rmdir,
  write,
}
