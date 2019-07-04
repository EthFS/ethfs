const cmds = require('../cmds')
const listPath = require('./listPath')

module.exports = async (kernel, line, callback) => {
  let path
  const emptyOrOneWord = line.match(/^\s*([^\s/]+)?$/)
  if (emptyOrOneWord) {
    path = emptyOrOneWord[1] || ''
  } else {
    const lastWord = line.match(/\S+$/)
    path = lastWord ? lastWord[0] : ''
  }
  const index = path.lastIndexOf('/') + 1
  const dirname = path.slice(0, index) || '.'
  const basename = path.slice(index)
  try {
    let keys = new Set(await listPath(kernel, dirname))
    if (emptyOrOneWord) {
      const bin = await listPath(kernel, '/bin')
      bin.forEach(x => keys.add(x))
      for (x in cmds) keys.add(x)
    }
    keys = Array.from(keys).sort()
    const hits = keys.filter(x => x.startsWith(basename))
    callback(null, [hits.length ? hits : keys, basename])
  } catch (e) {
    callback(null, [[]])
  }
}
