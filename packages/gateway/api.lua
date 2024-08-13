
local function createApis (args)
  local dal = args.dal

  assert(type(dal.query) == 'function', "dal MUST implement a 'query({ statments, parameters })' api")
  assert(type(dal.run) == 'function', "dal MUST implement a 'run({ statments, parameters })' api")

  --[[
  TODO implement:
    - findBlocks
    - findBlockById
    - findTransactions
    - findTransactionById
  ]]
end

return {
  createApis = createApis
}
