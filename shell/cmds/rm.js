const exec = require('./exec')
const {enc} = require('../utils/enc')

module.exports = async ({web3, kernel, args}) => {
  if (!args.length) {
    return console.log('Need an argument.')
  }
  let deltree
  if (args[0] === '-r') {
    args.shift()
    deltree = true
  }
  await args.reduce(async (promise, x) => {
    await promise
    if (deltree) {
      await exec(web3, kernel, '/bin/deltree', [x])
    } else {
      await kernel.unlink(enc(x))
    }
  }, Promise.resolve())
}
