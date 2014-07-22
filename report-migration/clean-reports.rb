require 'json'
require 'mongo'
require 'bson'
include Mongo

HOST_NAME = 'mongo1'
HOST_PORT = 27017
server = MongoClient.new HOST_NAME, HOST_PORT
db = server['stitch-cg']

cols = db.collection_names
cols.each do |col|
  if col.match /reports_/
    db[col].remove
  end
end
