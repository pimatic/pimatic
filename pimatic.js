#!/usr/bin/env node
require('coffee-script');
var path = require('path');
var fs = require('fs');
var init = require('./lib/daemon');
var semver = require('semver');

if(semver.lt(process.version, '0.9.0')) {
  console.log("Warning: You node.js version " + process.version + "seems to be very old. "
    + "Please update Node.js to >0.9.0 to run pimatic without problems!");
}

run = function () {
  require('./startup');
};

var command = process.argv[2];
if(!command || command === "run") {
  process.on('uncaughtException', function (err){
    if(!err.silent) {
      console.log('a uncaught exception occured: ', err.stack);
    }
    console.log('exiting...');
    process.exit(1);
  });
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

