async = require 'async'
mongo = require 'mongodb'
insertDataRow = require './insert-data'

dropReportCollections = (db, cb) ->
  db.open (err, db) ->
    db.collectionNames namesOnly: true, (err, cols) ->
      if err then return cb err
      cols = cols.map (col) ->
        match = col.match /stitch-cg\.(report.*)/
        if match then return match[1]
      cols = cols.filter (col) -> col
      async.forEach cols, (col, callback) ->
        db.dropCollection col, callback
      , cb

exitFn = (err) ->
  console.error err
  process.exit()

# Copy live reports from stitch and insert into stitch-cg, in
# new format

getLiveReports = (db, cb) ->
  query =
    live: 'live'
    not_active: $nin: ['true', true]
  db.collection 'reports', (err, col) ->
    col.find(query).toArray cb

convertToNewFormat = (reports) ->
  newReports = {}

  # Index reports
  reports.forEach (report) ->
    run = report.run_name
    view = report.view_id
    rep = report.report_name
    newReports[run] ?= {}
    newReports[run][view] ?= {
      reports: {}
    }
    newReports[run][view].reports[rep] = true

  converted = []
  for run,views of newReports
    for view,rep of views
      newReport =
        run_name: run
        view_id: view
        reports: rep.reports
      converted.push newReport
  console.log 'num reports: ' + converted.length
  return converted


insertNewReports = (dev, newReports, cb) ->
  dev.collection 'reports', (err, col) ->
    async.forEach newReports, (newReport, callback) ->
      query =
        run_name: newReport.run_name
        view_id: newReport.view_id
      col.update query, newReport, upsert: true, callback
    , cb

copyLiveReports = (stitch, dev, cb) ->
  getLiveReports stitch, (err, reports) ->
    newReports = convertToNewFormat reports
    insertNewReports dev, newReports, cb

#
# Copy report data
#

copyLiveReportData = (stitch, dev, cb) ->
  dev.collection 'reports', (err, col) ->
    col.find({}).toArray (err, devReports) ->
      console.log 'num dev reports ' + devReports.length
      async.eachSeries devReports, (report, callback) ->
        copySingleBuildData report, stitch, callback

copySingleBuildData = (report, stitch, cb) ->
  console.log "Copying " + JSON.stringify report, null, 2
  subreports = Object.keys report.reports
  async.eachSeries subreports, (subreport, callback) ->
    copySubReports report, subreport, stitch, callback
  , cb

copySubReports = (report, subreport, stitch, cb) ->
  stitch.collection 'reports', (err, col) ->
    query =
      run_name: report.run_name
      view_id: report.view_id
      report_name: subreport
    opts =
      sort: [['created_at', -1]]
    col.find(query, opts).toArray (err, items) ->
      report = items[0]
      report_id = report._id
      getSingleReportData stitch, report_id, report.view_id, subreport, (err, data) ->
        console.log 'got data for ' + report.run_name + ' ' + report.view_id + ' ' + subreport
        saveSingleReportData dev, data, subreport, report, cb

getSingleReportData = (stitch, reportId, viewId, reportName, cb) ->
  colName = "reports_#{viewId}_#{reportName}"
  stitch.collection colName, (err, col) ->
    if err then return cb err
    query = report_id: reportId
    col.find(query).toArray (err, dataRows) ->
      if err then return cb err
      reportData = dataRows.reduce (reportData, row) ->
        if row.data
          row.data = row.data.filter (elem) -> elem
        reportData = insertDataRow reportData, row.data, row.value
        return reportData
      , {}
      cb err, reportData

saveSingleReportData = (db, data, reportName, report, cb) ->
  # if dataRows.length < 50 and dataRows.length > 20
  console.log "Report: " + reportName
  console.log "Report id " + report._id
  # console.log JSON.stringify data, null, 2
  # console.log 'not implemented'
  db.collection 'reports_' + reportName, (err, col) ->
    if err then return cb err
    query =
      report_id: report._id
    col.update query, data, upsert: true, (err) ->
      if err then console.error "Error: " + err
      cb()

#
# Extract live reports from prod and insert them into dev
#
server = new mongo.Server 'mongo1', 27017, auto_reconnect: true
stitch = new mongo.Db 'stitch', server, safe: true
server2 = new mongo.Server 'mongo1', 27017, auto_reconnect: true
dev = new mongo.Db 'stitch-cg', server2, safe: true

stitch.open (err, stitch) ->
  if err then exitFn err
  dev.open (err, dev) ->
    if err then exitFn err
    # copyLiveReports stitch, dev, (err) ->
    #   if err then exitFn err
    copyLiveReportData stitch, dev, (err) ->
      exitFn err