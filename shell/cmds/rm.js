const {pathenc} = require('../utils/enc')

module.exports = async (kernel, cmd, args) => {
  await args.reduce(async (promise, x) => {
    await promise
    await kernel.unlink(pathenc(x))
  }, Promise.resolve())
}
