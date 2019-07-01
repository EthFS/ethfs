const moment = require('moment')
const Table = require('cli-table')
const {enc, dec} = require('../utils/enc')

module.exports = async (web3, kernel, cmd, args) => {
  if (!args.length) args = ['.']
  await args.reduce(async (promise, path, argIndex) => {
    await promise
    const {entries} = await kernel.stat(enc(path))
    const keys = []
    for (let i = 0; i < entries; i++) {
      keys.push(await kernel.readkeyPath(enc(path), i))
    }
    keys.sort()
    const table = new Table({
      chars: {
        'top': '', 'top-mid': '', 'top-left': '', 'top-right': '',
        'bottom': '', 'bottom-mid': '', 'bottom-left': '', 'bottom-right': '',
        'left': '', 'left-mid': '', 'mid': '', 'mid-mid': '',
        'right': '', 'right-mid': '', 'middle': ' ',
      },
      colAligns: [, 'right',, 'right'],
      style: {'padding-left': 0, 'padding-right': 0},
    })
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
      if (fileType === 'd') links = entries
      let size = entries
      if (fileType === 'c') {
        const code = await web3.eth.getCode(owner)
        size = code.length / 2 - 1
      }
      owner = owner.slice(0, 12) + '…'
      lastModified = moment(lastModified.toNumber() * 1e3)
      if (lastModified.year() === moment().year()) {
        lastModified = lastModified.format('DD MMM HH:mm')
      } else {
        lastModified = lastModified.format('DD MMM  YYYY')
      }
      if (fileType === 'd') key += '/'
      table.push([fileType, ` ${links}`, owner, ` ${size}`, lastModified, key])
    }, Promise.resolve())
    if (argIndex > 0) console.log()
    if (args.length > 1) console.log(`${path}:`)
    console.log(table.toString())
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
