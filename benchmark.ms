/* Place in front/apps/node-lib/countries */

require('mochiscript');
var async = require('async');
var countries = require('./index.ms');

var points = [
  // Somewhere in Nebraska
  { text  : "US",
    point : [ 41.58, -99.29 ] },
  // Near Montreal
  { text  : "US/CA border",
    point : [45.01, -73.45 ] },
  // Seattle, with lots of islands
  { text : "US/CA border, many islands",
    point : [48.5275, -123.1082] },
  // Estonia, with lots of islands and across the Baltic from Finland
  { text : "EE, many islands",
    point : [59.3332, 24.1461] },
  // Island near Greece and Turkey
  { text : "GR/TR, many islands",
    point : [37.0552, 25.4755] },
  // Near Argentina, Paraguay, Brazil border
  { text  : "Argentina / Paraguay / Brazil",
    point : [-26.4614, -54.4263] },
  // Near Croatia, Slovenia, Hungary border
  { text  : "Croatia, Slovenia, Hungary",
    point : [46.111, 16.589] }
];

var reps = 1;

function logTime(testType, start, end) {
  console.log(testType + " Elapsed: " + (end - start));
  console.log(testType + " Mean: " + (end - start) / reps);
}

function runSimple(point) {
  var start = +new Date();
  for (var i = 0; i < reps; i++) {
    countries.locateAll(point, true);
  }
  logTime("Simple", start, +new Date());
}

function runPrecise(point) {
  var start = +new Date();
  for (var i = 0; i < reps; i++) {
    countries.locateFine(point);
  }
  logTime("Precise", start, +new Date());
}

var funcs = points.map(function(sample) {
  return function(cb) {
    console.log(sample.text);
    runSimple(sample.point);
    runPrecise(sample.point);
    cb(null);
  };
});

async.waterfall(funcs, function(){ console.log("DONE") });
