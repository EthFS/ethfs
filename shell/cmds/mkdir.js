const {enc} = require('../utils/enc')

module.exports = async ({kernel, args}) => {
  await args.reduce(async (promise, x) => {
    await promise
    await kernel.mkdir(enc(x))
  }, Promise.resolve())
}
