const readline = require('readline')

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
})

function prompt(x) {
  return new Promise(resolve => rl.question(x || '> ', resolve))
}

module.exports = prompt
