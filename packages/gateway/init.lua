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

local function parseCustomDal (impl)
  local errs = {}

  if type(impl) ~= "table" then table.insert(errs, "custom dal must be a table") end

  impl = impl or {}
  if type(impl.findTransactionById) ~= 'function' then table.insert(errs, "custom dal must implement findTransactionById(id)") end
  if type(impl.findTransactions) ~= 'function' then table.insert(errs, "custom dal must implement findTransactions(criteria)") end
  if type(impl.saveTransaction) ~= 'function' then table.insert(errs, "custom dal must implement saveTransaction(doc)") end

  if #errs > 0 then assert(false, table.concat(errs, ',\n')) end

  -- TODO: ought we wrap with some sort of schema validation?

  return impl
end

Gateway.new = function (args)
  local self = setmetatable({}, Gateway)

  args = args or {}
  -- Kind defaults to 'new'
  self.kind = args.kind or 'new'
  self.continue = args.continue or false
  self.dal = args.dal or {}

  -- Create Data Access Layer
  local dal = nil

  -- The caller has provided a dal impl, so use that
  if self.dal.impl then
    dal = parseCustomDal(self.dal.impl)
    self.dal.type = 'custom'
  -- Use a pre-canned dal impl, defaulting to sqlite_json
  else
    local ok, buildDal = maybeRequire(string.format('@tilla/graphql_arweave_gateway.dal.%s.init', self.dal.type or 'sqlite_json'))
    -- pass args.persistence as options to dal implementation
    if ok then dal = buildDal()(self.dal)
    else assert(false, string.format('Persistence engine "%s" could not be loaded: %s', self.dal.type, tostring(dal))) end
  end

  -- Compose Business logic on top of data access layer
  local apis = api.createApis({ dal = dal })

  -- Expose apis
  self.index = apis.saveTransaction
  self.apis = apis
  self.dal = dal

  -- Create the GraphQL Server
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
  self.match = args.match or nil

  local function defaultMatch (msg)
    if msg.Cron then return false end

    -- Do not index Evals targeting this process
    if msg.Action == 'Eval' and msg.Target == ao.id then
      return false
    end

    -- Execute this handler, then keep flowing into subsequent handlers
    if self.continue then return 'continue' end
    -- Execute this handler, then stop
    return true
  end

  --[[
    Automatically attach an aos handler after the graphql handler
    that will save all messages that are not crons to the indexer
  ]]
  Handlers.after(self.gql.constants.aos.ServerHandler).add(
    'GraphQL.Indexer',
    function (msg)
      if self.match then return require('.utils').matchesSpec(msg, self.match) end
      return defaultMatch(msg)
    end,
    function (msg)
      self.apis.saveTransaction(msg)
      print(string.format('Saved msg "%s"', msg.Id))
    end
  )

  return self
end

return Gateway
