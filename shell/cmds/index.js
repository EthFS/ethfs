const cat = require('./cat')
const chdir = require('./chdir')
const exec = require('./exec')
const ls = require('./ls')
const mkdir = require('./mkdir')
const rm = require('./rm')
const rmdir = require('./rmdir')

module.exports = {
  cat,
  cd: chdir,
  chdir,
  exec,
  ls,
  mkdir,
  rm,
  rmdir,
}
