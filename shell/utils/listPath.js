const {enc, dec} = require('../utils/enc')

module.exports = async (kernel, path) => {
  path = enc(path)
  const {entries} = await kernel.stat(path)
  const keys = []
  for (let i = 0; i < entries; i++) {
    keys.push(await kernel.readkeyPath(path, i))
  }
  return keys.map(dec)
}
