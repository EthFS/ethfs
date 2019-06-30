const {enc, dec} = require('../utils/enc')

module.exports = async (web3, kernel, cmd, args) => {
  await args.reduce(async (promise, x) => {
    await promise
    const data = {}
    const path = enc(x)
    const keys = await kernel.listPath(path)
    await keys.reduce(async (promise, key) => {
      await promise
      const value = await kernel.readPath(path, key)
      data[dec(key)] = dec(value)
    }, Promise.resolve())
    console.log(JSON.stringify(data, null, 2))
  }, Promise.resolve())
}
