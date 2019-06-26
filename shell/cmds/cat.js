const {dec, pathenc} = require('../utils/enc')

module.exports = async (kernel, cmd, args) => {
  await args.reduce(async (promise, x) => {
    await promise
    const data = {}
    const path = pathenc(x)
    const keys = await kernel.list(path)
    await keys.reduce(async (promise, key) => {
      await promise
      const value = await kernel.read2(path, key)
      data[dec(key)] = dec(value)
    }, Promise.resolve())
    console.log(JSON.stringify(data, null, 2))
  }, Promise.resolve())
}
