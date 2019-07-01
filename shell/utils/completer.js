const listPath = require('./listPath')

module.exports = async (kernel, line, callback) => {
  try {
    const path = line.match(/\S+$/)[0]
    const index = path.lastIndexOf('/') + 1
    const dirname = path.slice(0, index) || '.'
    const basename = path.slice(index)
    const keys = await listPath(kernel, dirname)
    const hits = keys.filter(x => x.startsWith(basename))
    callback(null, [hits.length ? hits : keys, basename])
  } catch (e) {
    callback(null, [[]])
  }
}
