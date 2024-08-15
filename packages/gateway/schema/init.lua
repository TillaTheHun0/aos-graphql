local graphql = require('.graphql.init')

local schema, types = graphql.schema, graphql.types

local utils = require('.graphql.gateway.utils')

-- Mini schemas that are used to build out the entire schema
--[[
 TODO: the Block graphql schema is implemented, but not the
 persistence, and so this is not being included in the overall schema for now.

 In this sense, the gateway schema is partially implemented, only implementing
 transactions() and transaction() queries

 Once we figure out how indexers might receive sequential block
]]
local Block = require('.graphql.gateway.schema.block')
local Transaction = require('.graphql.gateway.schema.transaction')

local function gatherQueryFields (minis)
  return utils.reduce(
    function (fields, cur)
      for k, v in pairs(cur.queries) do fields[k] = v end
      return fields
    end,
    {},
    minis
  )
end

local _schema = schema.create({
  query = types.object({
    name = 'Query',
    fields = gatherQueryFields({ Transaction })
  })
})

return _schema
