const {dec} = require('../utils/enc')

module.exports = async ({kernel}) => {
  console.log(dec(await kernel.getcwd()))
}
