const readline = require('readline')

module.exports = completer => {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    completer,
  })
  return x => new Promise(resolve => rl.question(x || '> ', resolve))
}
