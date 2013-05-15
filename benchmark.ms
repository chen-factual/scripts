/* Place in front/apps/node-lib/countries */

require('mochiscript');
var async = require('async');
var countries = require('./index.ms');

// Somewhere in Nebraska
var point_US = [ 41.58, -99.29 ];
// Near US/CA border
var point_US_CA = [ 45.01, -73.45 ];
// Near Argentina, Paraguay, Brazil border
var point_RA_PY_BR = [ -26.4614, -54.4263 ];
// Near Croatia, Slovenia, Hungary border
var point_HR_SI_HU = [ 46.111, 16.589 ];

var reps = 100;

function runSimple(point) {
  var start = +new Date();
  for (var i = 0; i < reps; i++) {
    var ccs = countries.locateAll(point, true);
  }
  var end = +new Date();
  console.log("Simple Elapsed: " + (end - start));
  console.log("Simple Mean: " + (end - start) / reps);
}

function runPrecise(point, cb) {
  var start = +new Date();
  async.timesSeries(reps,
              function(err, cb) {
                countries.locateFine(point, cb);
              },
              function(err) {
                var end = +new Date();
                console.log("Precise Elapsed: " + (end - start));
                console.log("Precise Mean: " + (end - start) / reps);
                cb(null);
              }
             );
}


async.waterfall([
  function(cb) {
    console.log("US");
    runSimple(point_US);
    runPrecise(point_US, cb);
  },
  function(cb) {
    console.log("US/CA");
    runSimple(point_US_CA);
    runPrecise(point_US_CA, cb);
  },
  function(cb) {
    console.log("Argentina/Paraguay/Brazil");
    runSimple(point_RA_PY_BR);
    runPrecise(point_RA_PY_BR, cb);
  },
  function(cb) {
    console.log("Croatia/Slovenia/Hungary");
    runSimple(point_HR_SI_HU);
    runPrecise(point_HR_SI_HU, cb);
  }
],
  function(err, res) {
    console.log("DONE");
  }
);





