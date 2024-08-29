local server = require('@tilla/graphql_server.init')

local utils = require('@tilla/graphql_arweave_gateway.utils')
local api = require('@tilla/graphql_arweave_gateway.api')
local schema = require('@tilla/graphql_arweave_gateway.schema.init')

local Gateway = { _version = "0.0.1" }

local function maybeRequire(moduleName)
  local ok, result, err = pcall(require, moduleName)
  if ok then return ok, result
  else return ok, err end
end

Gateway.new = function (args)
  local self = setmetatable({}, Gateway)

  args = args or {}
  -- Kind defaults to 'new'
  self.kind = args.kind or 'new'
  self.continue = args.continue or false
  self.persistence = args.persistence or {}
  -- Persistence defaults to sqlite_json
  self.persistence.type = self.persistence.type or 'sqlite_json'

  -- Create Data Access Layer
  local ok, dal = maybeRequire(string.format('@tilla/graphql_arweave_gateway.dal.%s.init', self.persistence.type))
  if ok then
    -- pass args.persistence as options to dal implementation
    dal = dal()(self.persistence)
  else
    assert(false, string.format('Persistence engine "%s" could not be loaded: %s', self.persistence.type, tostring(dal)))
  end

  -- Compose Business logic on top of data access layer
  local apis = api.createApis({ dal = dal })

  -- Create the GraphQL Server
  self.apis = apis
  self.dal = dal
  self.gql = server[self.kind]({
    continue = self.continue,
    schema = schema,
    context = function (info)
      -- Expose apis on contextValue to all resolvers
      local contextValue = utils.mergeAll({ info, apis })
      return contextValue
    end
  })

  return self
end

Gateway.aos = function (args)
  args = args or {}
  args.kind = 'aos'

  local self = Gateway.new(args)

  self.continue = args.continue or false
  self.matchSpec = args.matchSpec or nil

  --[[
    Automatically attach an aos handler after the graphql handler
    that will save all messages that are not crons to the indexer
  ]]
  Handlers.after(self.gql.constants.aos.ServerHandler).add(
    'GraphQL.Arweave_Gateway',
    function (msg)
      -- Use custom matchSpec
      if self.matchSpec then return self.matchSpec(msg) end

      if msg.Cron then return false end
      -- Execute this handler, then keep flowing into subsequent handlers
      if self.continue then return 'continue' end
      -- Execute this handler, then stop
      return true
    end,
    function (msg)
      self.apis.saveTransaction(msg)
      print(string.format('Saved msg "%s"', msg.Id))
    end
  )

  return self
end

return Gateway
