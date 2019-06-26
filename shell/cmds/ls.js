const {dec, pathenc} = require('../utils/enc')

module.exports = async (kernel, cmd, args) => {
  if (!args.length) args = ['.']
  await args.reduce(async (promise, x) => {
    await promise
    const keys = await kernel.list(pathenc(x))
    keys.map(dec).forEach(x => console.log(x))
  }, Promise.resolve())
}
