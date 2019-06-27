const {pathenc} = require('../utils/enc')

module.exports = async (kernel, cmd, args) => {
  await kernel.exec(pathenc(cmd), pathenc(args[0]), pathenc(args[1]))
}
