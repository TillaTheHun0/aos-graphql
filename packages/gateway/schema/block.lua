local graphql = require('@tilla/graphql.init')

local utils = require('@tilla/graphql_arweave_gateway.utils')
local connection = require('@tilla/graphql_arweave_gateway.schema.connection')
local SortOrderSchema = require('@tilla/graphql_arweave_gateway.schema.sort_order')

local types = graphql.types
local ConnectionType, toConnection = connection.ConnectionType, connection.toConnection
local SortOrderEnum = SortOrderSchema.types.SortOrderEnum

local Block = types.object({
  name = "Block",
  description = [[
    Metadata for a block on Arweave
  ]],
  fields = {
    id = types.id.nonNull,
    timestamp = types.int.nonNull,
    height = types.int.nonNull,
    previous = types.id.nonNull
  }
})

local BlockQuery = {
  kind = Block,
  arguments = {
    id = types.string
  },
  resolve = function (_, arguments, ctx)
    local findBlockById = ctx.findBlockById
    local findLatestBlock = ctx.findLatestBlock

    local id = arguments ~= nil and arguments.id
    if (not id or id == '') then return findLatestBlock() end
    return findBlockById(id)
  end
}

local toBlockConnection = toConnection({
  --[[
    TODO: What should we include in the cursor here?
    all of the search criteria, plus the id?

    For now just using id, but may need something more opaque
    and encapsulates more info ie. the accompanying criteria
    for the result set
  ]]
  toCursor = function (args)
    local block = args.node
    -- "1485116"
    return tostring(block.height)
  end
})

local BlockFilterInput = types.inputObject({
  name = 'BlockFilter',
  description = 'Find blocks within a given range',
  fields = {
    min = {
      kind = types.int,
      description = 'Minimum block height to filter from'
    },
    max = {
      kind = types.int,
      description = 'Maximum block height to filter to'
    },
  }
})

local BlocksQuery = {
  kind = ConnectionType(Block),
  arguments = {
    ids = types.list(types.id.nonNull),
    height = BlockFilterInput,
    first = {
      kind = types.int,
      defaultValue = 10
    },
    after = types.string,
    sort = {
      kind = SortOrderEnum,
      defaultValue = SortOrderEnum.values.HEIGHT_DESC.name
    }
  },
  resolve = function (_, arguments, ctx)
    local findBlocks = ctx.findBlocks

    local sort = arguments.sort == SortOrderEnum.values.HEIGHT_DESC.value
      and 'desc'
      or 'asc'

    local limit = utils.clamp(1, 1000, arguments.first or 10)

    local criteria = {
      ids = arguments.ids,
      height = arguments.height,
      limit = limit,
      sort = sort
    }

    local blocks, nextBlock = findBlocks(criteria)

    return toBlockConnection({
      nodes = blocks,
      criteria = criteria,
      next = nextBlock,
      pageSize = limit
    })
  end
}

return {
  types = { Block = Block, BlockFilterInput = BlockFilterInput },
  queries = {
    block = BlockQuery,
    blocks = BlocksQuery
  }
}
