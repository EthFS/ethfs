const {enc} = require('../utils/enc')

module.exports = async (kernel, cmd, args) => {
  await args.reduce(async (promise, x) => {
    await promise
    await kernel.rmdir(enc(x))
  }, Promise.resolve())
}
