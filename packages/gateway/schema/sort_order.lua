local graphql = require('.graphql.init')

local types = graphql.types

local SortOrderEnum = types.enum({
  name = 'SortOrder',
  description = [[
    The order to sort the blocks in the result set
  ]],
  values = {
    HEIGHT_DESC = {
      description = [[
        Results are sorted by the transaction block height in descending order,
        with the most recent and unconfirmed/pending transactions appearing first.
      ]],
      value = 'HEIGHT_DESC',
    },
    HEIGHT_ASC = {
      description = [[
        Results are sorted by the transaction block height in ascending order,
        with the oldest transactions appearing first, and the most recent and pending/unconfirmed appearing last.
      ]],
      value = 'HEIGHT_ASC',
    }
  }
})

return {
  types = { SortOrderEnum = SortOrderEnum }
}
