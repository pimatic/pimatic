#!/usr/bin/env node
process.umask(0);
require('./coffee-cache.js')
var path = require('path');
var init = require('./lib/daemon');
var semver = require('semver');

if(semver.lt(process.version, '4.0.0')) {
  console.log("Error: Your node.js version " + process.version + " is too old. "
    + "Please update node.js to version >=4.0.0 and run pimatic again. See you again.");
  process.exit(1);
}

run = function () {
  require('./startup').startup().done();
};

var command = process.argv[2];
if(!command || command === "run") {
  run();
} else {
  logFile = path.resolve(__dirname, '../../pimatic-daemon.log');
  pidFile = path.resolve(__dirname, '../../pimatic.pid');

  init.simple({
    pidfile: pidFile,
    logfile: logFile,
    command: process.argv[3],
    run: run
  });
}

