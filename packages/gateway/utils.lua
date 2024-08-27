local utils = {}

utils.isArray = function (t)
  if type(t) == "table" then
    local maxIndex = 0
    for k, v in pairs(t) do
      -- If there's a non-integer key, it's not an array, so immediately return
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then return false end
      maxIndex = math.max(maxIndex, k)
    end
    -- If the highest numeric index is equal to the number of elements, it's an array
    return maxIndex == #t
  end
  return false
end

-- @param {function} fn
-- @param {number} arity
utils.curry = function (fn, arity)
    assert(type(fn) == "function", "function is required as first argument")
    arity = arity or debug.getinfo(fn, "u").nparams
    if arity < 2 then return fn end

    return function (...)
      local args = {...}

      if #args >= arity then
        return fn(table.unpack(args))
      else
        return utils.curry(function (...)
          return fn(table.unpack(args),  ...)
        end, arity - #args)
      end
    end
  end

-- @param {function} fn
-- @param {any} initial
-- @param {table<Array>} t
utils.reduce = utils.curry(function (fn, initial, t)
  assert(type(fn) == "function", "first argument should be a function that accepts (result, value, key)")
  assert(type(t) == "table" and utils.isArray(t), "third argument should be a table that is an array")
  local result = initial
  for k, v in ipairs(t) do result = fn(result, v, k) end
  return result
end, 3)

-- @param {function} fn
-- @param {table<Array>} data
utils.map = utils.curry(function (fn, t)
  assert(type(fn) == "function", "first argument should be a unary function")
  assert(type(t) == "table" and utils.isArray(t), "third argument should be a table that is an array")

  local function map (result, v, k)
    result[k] = fn(v, k)
    return result
  end

  return utils.reduce(map, {}, t)
end, 2)

utils.isNil = function (v) return v == nil end

utils.identity = function (x) return x end

utils.mergeAll = function (ts)
  local merged = {}
  for _, dict in ipairs(ts) do
    for key, value in pairs(dict) do merged[key] = value end
  end
  return merged
end

utils.clamp = utils.curry(function (min, max, v)
  assert(type(min) == 'number', 'min must be a number')
  assert(type(max) == 'number', 'max must be a number')
  assert(type(v) == 'number', 'v must be a number')
  assert(min <= max, "min must not be greater than max")

  return (v < min and min) or (v > max and max) or v
end, 3)

utils.startsWith = function (str, start)
  return string.sub(str, 1, string.len(start)) == start
end

utils.isEmpty = function (t) return next(t) == nil end

utils.complement = function (fn)
  return function (...) return not fn(...) end
end

utils.mutConcat = function (t1, t2)
  for i = 1, #t2 do table.insert(t1, t2[i]) end
  return t1
end

return utils
