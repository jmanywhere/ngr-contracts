### DEPLOY Script

## 1

`forge script script/NGR.s.sol:DeployNGR --broadcast -vv --rpc-url bsc_testnet`

## 2

`forge script script/NGR2.s.sol:DeployNGR --broadcast -vv --rpc-url bsc_testnet`

### FLATTEN Script

`forge flatten src/NGR.sol -o flat/FlatNGR.sol`
`forge flatten src/NGR_2.sol -o flat/FlatNGR2.sol`
