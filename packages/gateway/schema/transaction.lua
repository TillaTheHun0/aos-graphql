-- TODO: anyway to not require a module directly from aos?
local bint = require('.bint')(256)

local graphql = require('.graphql.init')

local utils = require('.graphql.gateway.utils')
local connection = require('.graphql.gateway.schema.connection')
local BlockSchema = require('.graphql.gateway.schema.block')
local SortOrderSchema = require('.graphql.gateway.schema.sort_order')

local types = graphql.types
local ConnectionType, toConnection = connection.ConnectionType, connection.toConnection
local Block, BlockFilterInput = BlockSchema.types.Block, BlockSchema.types.BlockFilterInput
local SortOrderEnum = SortOrderSchema.types.SortOrderEnum

local Owner = types.object({
  name = 'Owner',
  description = [[
    A transaction owner.
  ]],
  fields = {
    address = {
      kind = types.string.nonNull,
      description = [[
        The owner's wallet address
      ]]
    },
    key = {
      kind = types.string.nonNull,
      description = [[
        The owner's public key as a base64url encoded string
      ]]
    }
  }
})

local Amount = types.object({
  name = 'Amount',
  description = [[
    A value transfer between wallets, in both winson and ar
  ]],
  fields = {
    winston = {
      kind = types.string.nonNull,
      description = [[
        Amount as a winston string e.g. `"1000000000000"`
      ]]
    },
    -- Should this resolve using a derivation of winston?
    ar = {
      kind = types.string.nonNull,
      description = [[
        Amount as an AR string e.g. `"0.000000000001"`
      ]]
    }
  }
})

local MetaData = types.object({
  name = 'MetaData',
  description = [[
    Basic metadata about the transaction data payload
  ]],
  fields = {
    size = {
      kind = types.string.nonNull,
      description = [[
        Size of the associated data, in bytes
      ]]
    },
    type = {
      kind = types.string,
      description = [[
        Derived from the `content-type` tag on a transaction
      ]]
    }
  }
})

local Tag = types.object({
  name = 'Tag',
  description = [[
    A tag on a transaction
  ]],
  fields = {
    name = {
      kind = types.string.nonNull,
      description = [[
        UTF-8 tag name
      ]]
    },
    value = {
      kind = types.string.nonNull,
      description = [[
        UTF-8 tag value
      ]]
    }
  }
})

local Parent = types.object({
  name = 'Parent',
  description = [[
    The parent transaction for bundled transactions
    See: https://github.com/ArweaveTeam/arweave-standards/blob/master/ans/ANS-102.md.
  ]],
  fields = {
    id = types.id.nonNull
  }
})

local Bundle = types.object({
  name = 'Bundle',
  description = [[
    The data bundle containing the current data item.
    See: https://github.com/ArweaveTeam/arweave-standards/blob/master/ans/ANS-104.md
  ]],
  fields = {
    id = types.id.nonNull
  }
})

local function toAr (winston)
  local ar = bint(winston) / bint(1000000000000)
  return tostring(ar)
end

local ZERO_AMOUNT = { ar = '0', winston = '0' }
local function toAmount (winston)
  if winston == nil then return ZERO_AMOUNT end
  return { winston = tostring(winston), ar = toAr(winston) }
end

local Transaction = types.object({
  name = 'Transaction',
  description = [[
    A transaction on Arweave
  ]],
  fields = {
    id = types.id.nonNull,
    anchor = types.string.nonNull,
    signature = {
      kind = types.string.nonNull,
      resolve = function (transaction)
        -- TODO: does this need to take into account bundleId?
        -- See https://github.com/ar-io/ar-io-node/blob/f14a32ac6efe72cfb63e2e75ab50bd713adeeb04/src/routes/graphql/resolvers.ts#L86
        return transaction.signature or '<not-found>'
      end
    },
    recipient = {
      kind = types.string.nonNull,
      resolve = function (transaction)
        -- this is non-nullable in the schema
        -- so return empty string if value is not a string
        return type(transaction.recipient) == 'string'
          and transaction.recipient
          or ''
      end
    },
    owner = Owner.nonNull,
    fee = {
      kind = Amount.nonNull,
      resolve = function (transaction) return toAmount(transaction.fee) end
    },
    quantity = {
      kind = Amount.nonNull,
      resolve = function (transaction) return toAmount(transaction.quantity) end
    },
    data = MetaData.nonNull,
    tags = types.list(Tag.nonNull).nonNull,
    block = {
      -- nullable
      kind = Block,
      description = [[
        Transactions with a null block are recent and unconfirmed,
        if they aren't mined into a block within 60 minutes they will be removed from results.
      ]]
    },
    parent = {
      -- nullable
      kind = Parent,
      deprecationReason = 'Use `bundledIn`',
      resolve = function (transaction)
        return transaction.bundleId and { id = transaction.bundleId } or nil
      end
    },
    bundledIn = {
      -- nullable
      kind = Bundle,
      description = [[
        For bundled data items this references the containing bundle ID.
        See: https://github.com/ArweaveTeam/arweave-standards/blob/master/ans/ANS-104.md
      ]],
      resolve = function (transaction)
        return transaction.bundleId and { id = transaction.bundleId } or nil
      end
    }
  }
})

local TransactionQuery = {
  kind = Transaction,
  arguments = {
    id = types.id.nonNull
  },
  resolve = function (_, arguments, ctx)
    local findTransaction = ctx.findTransaction

    local id = arguments.id

    return findTransaction(id)
  end
}


local toTransactionConnection = toConnection({
  -- TODO: make more opaque
  toCursor = function (args)
    local transaction, criteria = args.transaction, args.criteria
    -- TODO:how to implement
    return transaction.id .. ',' .. criteria.sort
  end
})

local TagOperator = types.enum({
  name = 'TagOperator',
  description = [[
    The operator to apply to to the tag filter
  ]],
  values = {
    EQ = {
      value = 'EQ',
      description = [[ Equal ]]
    },
    NEQ = {
      value = 'NEQ',
      description = [[ Not equal ]]
    }
  }
})

local TagFilterInput = types.inputObject({
  name = 'TagFilter',
  description = [[
    Find transactions using tags
  ]],
  fields = {
    name = types.string.nonNull,
    values = types.list(types.string.nonNull).nonNull,
    op = {
      kind = TagOperator,
      default = TagOperator.values.EQ.name
    }
  }
})

local TransactionsQuery = {
  kind = ConnectionType(Transaction),
  arguments = {
    ids = types.list(types.id.nonNull),
    owners = types.list(types.string.nonNull),
    recipients = types.list(types.string.nonNull),
    tags = types.list(TagFilterInput.nonNull),
    bundledIn = types.list(types.id.nonNull),
    block = BlockFilterInput,
    first = {
      kind = types.int,
      defaultValue = 10
    },
    after = types.string,
    sort = {
      kind = SortOrderEnum,
      defaultValue = SortOrderEnum.values.HEIGHT_DESC.value
    }
  },
  resolve = function (_, arguments, ctx)
    local findTransactions = ctx.findTransactions

    local limit = arguments.first

    local sort = arguments.sort == SortOrderEnum.values.HEIGHT_DESC.value
      and 'desc'
      or 'asc'

    local minHeight = arguments.block and arguments.block.min or nil
    local maxHeight = arguments.block and arguments.block.max or nil

    local bundledIn = arguments.bundledIn
      and arguments.bundledIn
      or arguments.parent

    local tags = arguments.tags or {}

    local transactions, nextTransaction = findTransactions({
      ids = arguments.ids,
      recipients = arguments.recipients,
      owners = arguments.owners,
      minHeight = minHeight,
      maxHeight = maxHeight,
      bundledIn = bundledIn,
      tags = tags,
      limit = limit,
      sort = sort
    })

    return toTransactionConnection({
      nodes = transactions,
      next = nextTransaction,
      pageSize = limit
    })
  end
}

return {
  types = { Transaction = Transaction },
  queries = {
    transaction = TransactionQuery,
    transactions = TransactionsQuery
  }
}
