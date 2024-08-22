
local function create ()
  local json = require('json')
  local sqlite3 = require('lsqlite3')

  local utils = require('@tilla/graphql_arweave_gateway.utils')

  local isNotEmpty = utils.complement(utils.isEmpty)

  --[[
    A simple, single-table schema, for storing transactions.
    We will leverage SQLites JSON selector to implement querying
    based on the search crtieria
  ]]

  local created = false

  --[[
    A simple, single-table schema, for storing transactions.
    We will leverage SQLites JSON selector to implement querying
    based on the search crtieria.

    Some columns store JSON:
    - owner
    - tags
    - block
  ]]
  local CREATE_TRANSACTIONS = [[
    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      anchor TEXT,
      signature TEXT,
      owner TEXT,
      fee INTEGER,
      quantity INTEGER,
      tags TEXT,
      block TEXT,
      bundle_id TEXT,
      recipient TEXT,
      timestamp INTEGER
    ) WITHOUT ROWID;
  ]]

  local function createSchema (client)
    if not created then
      client:exec(CREATE_TRANSACTIONS)

      created = true
    end

    return client
  end

  local function toDoc (row)
    local doc = {
      id = row.id,
      anchor = row.anchor,
      signature = row.signature,
      owner = row.owner
        and json.decode(row.owner)
        or {},
      fee = row.fee,
      quantity = row.quantity,
      tags = row.tags
        and json.decode(row.tags)
        or {},
      block = row.block
        and json.decode(row.block)
        or {},
      bundleId = row.bundle_id,
      recipient = row.recipient
    }

    return doc
  end

  return function (args)
    local DONE = sqlite3.DONE
    local ROW = sqlite3.ROW
    local client = args.client or sqlite3.open_memory()

    -- Bootstrap the schema
    createSchema(client)

    local function query (input)
      local sql, params = input.sql, input.params

      local stmt = client:prepare(sql)
      stmt:bind_values(table.unpack(params))

      local results = {}
      while true do
        local row = stmt:step()
        if row == ROW then
          table.insert(results, stmt:get_named_values())
        elseif row == DONE then break
        else
          error(string.format('"%s" statement failed: "%s"', sql, client:errmsg()))
        end
      end

      stmt:finalize()
      return results
    end

    local function run (input)
      local sql, params = input.sql, input.params

      local stmt = client:prepare(sql)
      stmt:bind_values(table.unpack(params))

      if stmt:step() ~= DONE then
        error(string.format('"%s" statement failed: "%s"', sql, client:errmsg()))
      end

      stmt:finalize()
    end

    local dal = {}

    dal.findTransactionById = function (id)
      local sql = [[
        SELECT *
        FROM transactions t
        WHERE
          t.id = ?;
      ]]
      local params = { id }

      --[[
        TODO: only select specific rows that we need
        to map
      ]]
      local row = query({ sql = sql, params = params })

      return (row and #row > 0 and toDoc(row[1])) or nil
    end

    dal.findTransactions = function (criteria)
      local sql = {
        'SELECT * FROM transactions t'
      }
      local params = {}

      if (criteria and isNotEmpty(criteria)) then
        table.insert(sql, 'WHERE')
        -- TODO: build out criteria
      end

      local rows = query({ sql = sql, params = params })

      return utils.map(toDoc, rows)
    end

    local function maybeJson (v) return v and json.encode(v) or nil end

    local transformations = {
      { 'id', utils.identity },
      { 'anchor', utils.identity },
      { 'signature', utils.identity },
      { 'owner', maybeJson },
      { 'fee', utils.identity },
      { 'quantity', utils.identity },
      { 'tags', maybeJson },
      { 'block', maybeJson },
      { 'bundle_id', utils.identity },
      { 'recipient', utils.identity },
      { 'timestamp', utils.identity }
    }
    dal.saveTransaction = function (doc)
      local cols = {}
      local values = {}
      local params = {}

      for _, pair in ipairs(transformations) do
        local col, transformation = table.unpack(pair)
        table.insert(cols, col)

        --[[
          Map the value to the appropriate parameter and value
          in the SQL statement
        ]]
        local transformed = transformation(doc[col])

        if transformed then
          table.insert(values, "?")
          table.insert(params, transformed)
        else
          table.insert(values, "NULL")
        end
      end

      local sql = string.format(
        [[
          INSERT INTO transactions (%s)
          VALUES (%s)
          ON CONFLICT DO NOTHING;
        ]],
        table.concat(cols, ', '),
        table.concat(values, ', ')
      )

      local res = run({ sql = sql, params = params })

      return res
    end

    return dal
  end

end

return create
