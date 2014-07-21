request = require 'request'

MASTERMIND = "http://mastermind.corp.factual.com:8070/"

getTask = () ->
  body =
    "batch.worktype_id": "top_records"
    name: 'fr test2 612'
  request.get
    url: MASTERMIND + 'tasks'
    body: JSON.stringify body
    headers: 'Content-Type': "application/json"
  , (err, resp, body) ->
    console.log err
    console.log body.length

getTask()