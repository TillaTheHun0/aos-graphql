
local utils = require('@tilla/graphql_arweave_gateway.utils')

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

  --[[
    TODO: some fields are not present on a msg and so are currently mapped to nil:
    - fee
    - quantity
    - bundle_id
    - block related metadata (timestamp, id, previous -- we _do_ have height)
  ]]
  apis.saveTransaction = function (msg)
    local doc = {
      id = msg.Id,
      anchor = msg.Anchor,
      signature = msg.Signature,
      owner = {
        address = msg.Owner
      },
      fee = nil,
      quantity = nil,
      tags = msg.TagArray,
      block = {
        id = nil,
        height = msg['Block-Height'],
        timestamp = nil,
        previous = nil
      },
      bundle_id = nil,
      recipient = msg.Target,
      timestamp = msg.Timestamp
    }

    dal.saveTransaction(doc)

    return doc
  end

  return apis
end

return {
  createApis = createApis
}
