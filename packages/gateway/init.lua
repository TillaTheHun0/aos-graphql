local server = require('@tilla/graphql_server.init')

local utils = require('@tilla/graphql_arweave_gateway.utils')
local api = require('@tilla/graphql_arweave_gateway.api')
local schema = require('@tilla/graphql_arweave_gateway.schema.init')

local gateway = { _version = "0.0.1" }

local function maybeRequire(moduleName)
  local ok, result, err = pcall(require, moduleName)
  if ok then return ok, result
  else return ok, err end
end

local function createServer (kind)
  return function (args)
    args = args or {}
    args.persistence = args.persistence or {}
    -- Persistence defaults to sqlite_json
    local pType = args.persistence.type or 'sqlite_json'

    -- Create Data Access Layer
    local ok, dal = maybeRequire('@tilla/graphql_arweave_gateway.dal.' .. pType .. '.init')
    if ok then
      -- pass args.persistence as options to dal implementation
      dal = dal()(args.persistence)
    else
      assert(false, string.format('Persistence engine "%s" could not be loaded: %s', pType, tostring(dal)))
    end

    -- Compose Business logic on top of data access layer
    local apis = api.createApis({ dal = dal })

    -- Create the GraphQL Server
    local gql = server[kind]({
      schema = schema,
      context = function (info)
        -- Expose apis on contextValue to all resolvers
        local contextValue = utils.mergeAll({ info, apis })
        return contextValue
      end
    })

    --[[
      Automatically attach an aos handler after the graphql handler
      that will save all messages that are not crons to the indexer
    ]]
    if kind == 'aos' then
      Handlers.after(gql.constants.aos.ServerHandler).add(
        'GraphQL.Arweave_Gateway',
        function (msg)
          if msg.Cron then return false end
          -- Execute this handler, then keep flowing into subsequent handlers
          if args.debug then return 'continue' end
          -- Execute this handler, then stop
          return true
        end,
        function (msg)
          apis.saveTransaction(msg)
          print(string.format('Saved msg "%s"', msg.Id))
        end
      )
    end

    -- Expose both the gql server and the bl apis
    return gql, apis
  end
end

gateway.new = createServer('new')
gateway.aos = createServer('aos')

return gateway
