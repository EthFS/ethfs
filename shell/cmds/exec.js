const {enc, pathenc} = require('../utils/enc')

module.exports = async (kernel, cmd, args) => {
  await kernel.exec(pathenc(cmd), args.map(enc))
}
