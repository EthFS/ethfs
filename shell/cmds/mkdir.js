const {enc} = require('../utils/enc')

module.exports = async (web3, kernel, cmd, args) => {
  await args.reduce(async (promise, x) => {
    await promise
    await kernel.mkdir(enc(x))
  }, Promise.resolve())
}
