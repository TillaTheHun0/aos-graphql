
local function create ()
  local json = require('json')
  local sqlite3 = require('lsqlite3')

  local utils = require('@tilla/graphql_arweave_gateway.utils')

  -- not nil and not empty
  local isNotNempty = function (v)
    return not (v == nil or utils.isEmpty(v))
  end

  --[[
    A simple, single-table schema, for storing transactions.
    We will leverage SQLites JSON selector to implement querying
    based on the search crtieria
  ]]

  local created = false
  local DONE = sqlite3.DONE
  local ROW = sqlite3.ROW

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
      bundle_id = row.bundle_id,
      recipient = row.recipient,
      timestamp = row.timestamp
    }

    return doc
  end

  local function toParameters (count)
    return string.rep('?', count, ',')
  end

  local function queryWith (client)
    return function (input)
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
  end

  local function runWith (client)
    return function (input)
      local sql, params = input.sql, input.params

      local stmt = client:prepare(sql)
      stmt:bind_values(table.unpack(params))

      if stmt:step() ~= DONE then
        error(string.format('"%s" statement failed: "%s"', sql, client:errmsg()))
      end

      stmt:finalize()
    end
  end

  return function (args)
    local client = args.client or sqlite3.open_memory()

    -- Bootstrap the schema
    createSchema(client)

    local doQuery = queryWith(client)
    local doRun = runWith(client)

    local dal = {}

    dal.client = client
    dal.query = doQuery
    dal.run = doRun

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
      local row = doQuery({ sql = sql, params = params })

      return (row and #row > 0 and toDoc(row[1])) or nil
    end

    dal.findTransactions = function (criteria)
      criteria = criteria or {}
      local query = {'SELECT * FROM transactions t'}
      local wheres = {}
      local params = {}

      -- ids
      if isNotNempty(criteria.ids) then
        table.insert(wheres, string.format('t.id IN (%s)', toParameters(#criteria.ids)))
        utils.mutConcat(params, criteria.ids)
      end

      -- owners
      if isNotNempty(criteria.owners) then
        table.insert(
          wheres,
          string.format("json_extract(t.owner, '$.address') IN (%s)", toParameters(#criteria.owners))
        )
        utils.mutConcat(params, criteria.owners)
      end

      -- recipients
      if isNotNempty(criteria.recipients) then
        table.insert(wheres, string.format('t.recipient IN (%s)', toParameters(#criteria.recipients)))
        utils.mutConcat(params, criteria.recipients)
      end

      -- tags
      if isNotNempty(criteria.tags) then
        for _, tag in ipairs(criteria.tags) do
          table.insert(
            wheres,
            string.format(
              "EXISTS (SELECT 1 FROM json_each(t.tags) WHERE json_each.value->>'$.name' = ? AND json_each.value->>'$.value' %sIN (%s))",
              tag.op == 'NEQ' and 'NOT ' or '',
              toParameters(#tag.values)
            )
          )
          table.insert(params, tag.name)
          utils.mutConcat(params, tag.values)
        end
      end

      -- bundleIn
      if isNotNempty(criteria.bundledIn) then
        table.insert(wheres, string.format('t.bundle_id IN (%s)', toParameters(#criteria.bundledIn)))
      end

      -- block
      if isNotNempty(criteria.block) then
        local block = criteria.block
        if block.min and block.max then
          table.insert(
            wheres,
            "json_extract(block, '$.height') >= ? AND json_extract(block, '$.height') <= ?"
          )
          utils.mutConcat(params, { block.min, block.max })
        elseif block.min then
          table.insert(wheres, "json_extract(block, \'$.height\') >= ?")
          table.insert(params, block.min)
        elseif block.max then
          table.insert(wheres, "json_extract(block, \'$.height\') <= ?")
          table.insert(params, block.max)
        end
      end

      --[[
        Produce an offset

        Since results are always ordered by block height asc or desc
        we can offset within the result set using an additional where clause
        w.r.t block height and timestamp

        So use the after to determine the direction being traversed (asc, desc)
        and which block to use
      ]]
      if isNotNempty(criteria.after) then
        local height, timestamp = criteria.after.height, criteria.after.timestamp
        table.insert(
          wheres,
          string.format(
            "json_extract(block, \'$.height\') %s ? OR (json_extract(block, \'$.height\') = ? AND timestamp %s ?)",
            criteria.sort == 'asc' and '>' or '<',
            criteria.sort == 'asc' and '>' or '<'
          )
        )
        utils.mutConcat(params, { height, height, timestamp })
      end

      -- Construct the where clause
      if #wheres > 0 then
        table.insert(query, string.format('WHERE %s', table.concat(wheres, ' AND ')))
      end

      -- Construct the order by clause
      if criteria.sort then
        local order = criteria.sort == 'asc' and 'ASC' or 'DESC'
        local orderBy = string.format(
          --[[
            Always sort by block height first, but then by timestamp
            so that results are predictably ordered in the results sets
          ]]
          "json_extract(t.block, '$.height') %s, timestamp %s",
          order,
          order
        )
        table.insert(query, string.format('ORDER BY %s', orderBy))
      end

      -- Construct the limit clause
      if criteria.limit then
        table.insert(query, string.format('LIMIT %d', criteria.limit))
      end

      -- construct the query
      table.insert(query, ';')
      local sql = table.concat(query, " ")

      local rows = doQuery({ sql = sql, params = params })

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
        table.concat({
          "INSERT INTO transactions (%s)",
          "VALUES (%s)",
          "ON CONFLICT DO NOTHING;"
        }, ' '),
        table.concat(cols, ', '),
        table.concat(values, ', ')
      )

      local res = doRun({ sql = sql, params = params })

      return res
    end

    return dal
  end

end

return create
