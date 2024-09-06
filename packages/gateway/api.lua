
local utils = require('@tilla/graphql_arweave_gateway.utils')

local Apis = {}

function Apis.new (args)
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
      min is 1
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

    -- The result set is smaller than the requested limit, so there is no next
    if #transactions <= limit then return transactions, nil end

    -- split between result set and next
    local results, _next = {}, nil
    for i = 1, limit do table.insert(results, transactions[i]) end
    _next = transactions[nextIdx]

    return results, _next
  end

  apis.saveTransaction = function (msg)
    local MsgBlock = msg.Block or {}

    local block = {}
    block.id = MsgBlock.Id or msg['Block-Id']
    block.height = MsgBlock.Height or msg['Block-Height']
    block.timestamp = MsgBlock.Timestamp or msg['Block-Timestamp']
    block.previous = MsgBlock.Previous or msg['Block-Previous']

    local transaction = {
      id = msg.Id,
      anchor = msg.Anchor,
      signature = msg.Signature,
      owner = {
        address = msg.Owner
      },
      fee = msg.Fee,
      quantity = msg.Quantity,
      tags = msg.TagArray,
      block = block,
      bundle_id = msg['Bundle-Id'],
      recipient = msg.Target,
      timestamp = msg.Timestamp
    }

    dal.saveTransaction(transaction)

    return transaction
  end

  return apis
end

return Apis
