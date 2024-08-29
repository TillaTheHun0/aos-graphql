(function ()
  -- START APM
  require('.graphql.runtime')
  require('.graphql.server')
  require('.graphql.gateway')
  -- END APM

  local gateway = require('@tilla/graphql_arweave_gateway')

  Gateway = gateway.aos({ continue = true })
end)()
