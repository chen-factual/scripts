insertDataRow = (obj, keys, value) ->
  if keys.length is 1
    obj ?= {}
    obj[keys[0]] = value
  else if obj
    if keys[0] of obj and obj[keys[0]] instanceof Object
      insertDataRow obj[keys[0]], keys.slice(1), value
    else
      subObj = insertDataRow {}, keys.slice(1), value
      obj[keys[0]] = subObj
  else
    obj = insertDataRow {}, keys, value
  return obj

log = (obj) ->
  console.log JSON.stringify obj, null, 2

test = () ->
  obj = insertDataRow {}, ['a', 'b'], 3
  log obj
  obj = insertDataRow obj, ['a', 'b'], 4
  log obj
  obj = insertDataRow obj, ['b', 'c'], 5
  log obj
  obj = insertDataRow obj, ['b', 'd'], 6
  log obj
  obj = insertDataRow obj, ['a'], 4
  log obj
  obj = insertDataRow obj, ['a', 'b'], 4
  log obj

module.exports = insertDataRow
