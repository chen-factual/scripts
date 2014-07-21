mongo = require('mongodb')

processIndex = (err, index, col) ->
  if err then throw err
  if index?
    if index._id is 'Iw1HPj-live'
      host = 'http://hp06:12003/'
    else if /stable/i.test(index.view_type) and /places/i.test(index.table_type)
      host = 'http://hp06:12006/'
    else
      host = 'http://hp06:12004/'
    solr_url = host + 'solr/' + index.view_id
    index.solr_url = solr_url
    if index.summaries_params?
      index.summaries_params.index_info.full_solr_url = solr_url
    col.update _id: index._id, index, (err,item) ->
      if err then throw err
      if item isnt 1 then throw new Error 'failed write'
  else
    console.log 'done!'

server = new mongo.Server 'mongo1', 27017, auto_reconnect: true
conn = new mongo.Db 'stitch', server, safe: true
conn.open (err, db) ->
  if err then throw err
  db.collection 'stitch-cores', (err, col) ->
    if err then throw err
    query = _id: /-live/, group: 'current'
    col.find query, (err, cursor) ->
      if err
        throw err
      else
        cursor.each (err, item) ->
          processIndex err, item, col
