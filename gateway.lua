(function ()
  local gateway = require('.graphql.gateway.init')

  local gql = gateway.create()
  return gql
end)()
