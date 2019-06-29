const moment = require('moment')
const {enc, dec} = require('../utils/enc')

module.exports = async (kernel, cmd, args) => {
  if (!args.length) args = ['.']
  await args.reduce(async (promise, path) => {
    await promise
    const keys = await kernel.listPath(enc(path))
    keys.sort()
    await keys.map(dec).reduce(async (promise, key) => {
      await promise
      let {
        fileType,
        permissions,
        links,
        owner,
        entries,
        lastModified,
      } = await kernel.stat(enc(`${path}/${key}`))
      fileType = fileTypeToChar(fileType)
      owner = owner.toLowerCase()
      owner = `${owner.slice(2, 6)}..${owner.slice(-4)}`
      lastModified = moment(lastModified.toNumber() * 1e3)
      if (lastModified.year() === moment().year()) {
        lastModified = lastModified.format('DD MMM HH:mm')
      } else {
        lastModified = lastModified.format('DD MMM  YYYY')
      }
      if (fileType === 'd') key += '/'
      console.log(`${fileType} ${links} ${owner} ${entries} ${lastModified} ${key}`)
    }, Promise.resolve())
  }, Promise.resolve())
}

function fileTypeToChar(fileType) {
  const Contract = 1
  const Data = 2
  const Directory = 3

  switch (fileType.toNumber()) {
    case Contract: return 'c'
    case Data: return '-'
    case Directory: return 'd'
  }
}
