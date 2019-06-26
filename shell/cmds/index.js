const cat = require('./cat')
const chdir = require('./chdir')
const exec = require('./exec')
const ls = require('./ls')

module.exports = {
  cat,
  cd: chdir,
  chdir,
  exec,
  ls,
}
