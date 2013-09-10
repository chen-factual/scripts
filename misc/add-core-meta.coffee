require 'mochiscript'
async = require 'async'
mongo = require './mongo-server'
screws = require './screws-cache'

mongo.find 'stitch-cores', {}, (err, cursor) ->
  count = 0
  process = (item, cb) ->
    count++
    screws.getViewInfo item.view_id, (err, seed) ->
      if err then return cb()
      changed = false
      if seed.country?
        item.country = seed.country
        changed = true
      if seed.viewName?
        item.view_type = seed.viewName
        changed = true
      if seed.category?
        item.table_type = seed.category
        changed = true
      if changed is true
        mongo.update 'stitch-cores', { _id: item._id }, item, (err) ->
          cb()
      else
        console.log "unchanged view: " + item.view_id
        cb()

  done = (err) ->
    console.log "Count: " + (count - 1)

  cursor.toArray (err, items) ->
    async.forEachLimit items, 1, process, done
