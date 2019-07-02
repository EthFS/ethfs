const readline = require('readline')

let rl

function create(completer) {
  rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    completer,
  })
}

function prompt(x) {
  return new Promise(resolve => rl.question(x || '> ', resolve))
}

module.exports = {
  create,
  prompt,
}
