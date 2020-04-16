EthFS - A Unix-like filesystem for Ethereum
===========================================

Getting started
---------------

1. Install dependencies: `yarn install`
2. Install truffle if it isn't already: `yarn global add truffle`
3. Create a file `.secret` containing the private key of the account to be used for deployment.
4. Install contracts to blockchain: `truffle migrate --network <network name e.g. ropsten>`
5. Mount the FUSE filesystem: `node fuse -p <mount point e.g. /mnt> -n <network name e.g. ropsten>`
