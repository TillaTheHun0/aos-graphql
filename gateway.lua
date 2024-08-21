(function ()
  local gateway = require('.graphql.gateway.init')

  local gql, apis = gateway.create({ continue = true })
  return gql, apis
end)()
