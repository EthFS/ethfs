const {dec} = require('../utils/enc')

module.exports = async (web3, kernel, cmd, args) => {
  console.log(dec(await kernel.getcwd()))
}
