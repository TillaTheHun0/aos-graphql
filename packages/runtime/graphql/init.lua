local graphql = { _version = '0.0.1' }

graphql.parse = require('@tilla/graphql.parse')
graphql.types = require('@tilla/graphql.types')
graphql.schema = require('@tilla/graphql.schema')
graphql.validate = require('@tilla/graphql.validate')
graphql.execute = require('@tilla/graphql.execute')
graphql.version = require('@tilla/graphql.version')

return graphql
