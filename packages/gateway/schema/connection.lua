local graphql = require('@tilla/graphql.init')

local utils = require('@tilla/graphql_arweave_gateway.utils')

local types = graphql.types

local identity = utils.identity

local PageInfo = types.object({
  name = 'PageInfo',
  description = [[
    Paginated page info using the GraphQL cursor spec.
  ]],
  fields = {
    hasNextPage = types.boolean.nonNull
  }
})

local function ConnectionType (gqlType)
  local edge = types.object({
    name = gqlType.name .. 'Edge',
    description = [[
      Paginated result set using the GraphQL cursor spec.
    ]],
    fields = {
      cursor = {
        kind = types.string.nonNull,
        description = [[
          The opaque cursor value that represents this node's position in the result set
        ]]
      },
      node = gqlType.nonNull
    }
  })

  return types.object({
    name = gqlType.name .. 'Connection',
    description = [[
      Paginated result set using the GraphQL cursor spec,
      see: https://relay.dev/graphql/connections.htm.
    ]],
    fields = {
      pageInfo = PageInfo,
      edges = types.list(edge.nonNull).nonNull
    }
  })
end

local function toConnection(builders)
  local toCursor = builders.toCursor
  local toNode = builders.toNode or identity

  return function(input)
    local nodes = input.nodes
    local hasNextPage = input.next and true
    local pageSize = input.pageSize

    -- Create pageInfo
    local pageInfo = {
      hasNextPage = hasNextPage
    }

    -- Create edges
    local edges = {}
    local count = 0
    for i, node in ipairs(nodes) do
      if count >= pageSize then break end
      table.insert(edges, { node = toNode(node), cursor = toCursor(node) })
      count = count + 1
    end

    return {
      pageInfo = pageInfo,
      edges = edges
    }
  end
end

return {
  ConnectionType = ConnectionType,
  toConnection = toConnection
}
