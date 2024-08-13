local graphql = require('.graphql.init')

local schema, types = graphql.schema, graphql.types

local utils = require('.graphql.gateway.utils')

-- Mini schemas that are used to build out the entire schema
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
    fields = gatherQueryFields({ Block, Transaction })
  })
})

return _schema
