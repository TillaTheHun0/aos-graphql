local server = require('.graphql.server.init')

local utils = require('.graphql.gateway.utils')
local api = require('.graphql.gateway.api')
local schema = require('.graphql.gateway.schema.init')

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
    local ok, dal = maybeRequire('.graphql.gateway.dal.' .. pType .. '.init')
    -- local ok, dal = true, require('.graphql.gateway.dal.sqlite_json.init')
    if ok then
      -- pass args.persistence as options to dal implementation
      dal = dal(args.persistence)
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
      Handlers.after('graphql').add(
        'saveTransaction',
        function (msg)
          if msg.Cron then return false end

          -- keep flowing through subsequent handlers
          if args.continue then return 'continue' end

          -- stop handler flow after this one executes
          return true
        end,
        function (msg)
          apis.saveTransaction(msg)
          print(string.format('Saved msg "%s". You may query it from the graph', msg.Id))
        end
      )
    end

    -- Expose both the gql server and the bl apis
    return gql, apis
  end
end

local create = createServer('create')
local aos = createServer('aos')

return { create = create, aos = aos }
