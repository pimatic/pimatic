#!/usr/bin/env node
var path = require('path');
var fs = require('fs');

logFile = path.resolve(__dirname, '../../pimatic-daemon.log');
pidFile = path.resolve(__dirname, '../../pimatic.pid');
var options = {
  logFile: logFile,
  outFile: logFile,
  errFile: logFile,
  pidFile: pidFile,
  cwd: __dirname,
  env: { 'PIMATIC_DAEMONIZED': true },
  max: 30 //the script will run 30 times at most
};

resolveSymLinks = function(script) {
  try{
    while(true){
      try{
        script = path.resolve(path.dirname(script), fs.readlinkSync(script));
      }catch(e) {
        if(e.code === 'EINVAL') {
          dir = path.dirname(script);
          if(dir !== '') {
            script = path.resolve(path.dirname(dir), fs.readlinkSync(dir), path.basename(script));
          }
        }
      }
    }
  }catch(e) {
    if(e.code !== 'EINVAL') {
      throw e;
    }
  }
  return script;
};

process.argv[1] = resolveSymLinks(process.argv[1]);

require('start-stop-daemon')(options, function() {
  require('coffee-script');
  require('./startup');
});

