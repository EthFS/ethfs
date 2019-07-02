const {enc, dec} = require('../utils/enc')

module.exports = async (web3, kernel, cmd, args) => {
  await args.reduce(async (promise, x) => {
    await promise
    const data = {}
    const path = enc(x)
    const {entries} = await kernel.stat(path)
    for (let i = 0; i < entries; i++) {
      const key = await kernel.readkeyPath(path, i)
      let value = dec(await kernel.readPath(path, key))
      try {
        value = JSON.parse(value)
      } catch(e) {}
      data[dec(key)] = value
    }
    console.log(JSON.stringify(data, null, 2))
  }, Promise.resolve())
}
