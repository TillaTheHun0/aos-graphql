
local utils = require('.graphql.gateway.utils')

local function createApis (args)
  local dal = args.dal

  local apis = {}

  apis.findBlockById = function (id)
    assert(false, 'findByBlockId not implemented')
  end

  apis.findBlocks = function (criteria)
    assert(false, 'findBlocks not implemented')
  end

  apis.findTransactionById = function (id)
    local transaction =  dal.findTransactionById(id)

    -- TODO: add any BL to map persistence model

    return transaction
  end

  apis.findTransactions = function (criteria)
    --[[
      default is 10
      max is 1000
    ]]
    local limit = utils.clamp(1, 1000, criteria.limit or 10)
    local nextIdx = limit + 1

    local transactions = dal.findTransactions(utils.mergeAll({
      criteria,
      --[[
        fetch an additional record from persistence to determine
        whether or not there are additional records in the result set
      ]]
      { limit = nextIdx }
    }))

    -- TODO: add any BL to map persistence model

    local nextTransaction = transactions[nextIdx]

    return transactions, nextTransaction
  end

  apis.saveTransaction = function (transaction)
    -- TODO map transaction to doc
    local doc = {}

    dal.saveTransaction(doc)

    return doc
  end

  return apis
end

return {
  createApis = createApis
}
