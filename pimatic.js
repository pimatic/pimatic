#!/usr/bin/env node
require('coffee-script');
var path = require('path');
var fs = require('fs');
var init = require('./lib/daemon');

run = function () {
  require('./startup');
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

