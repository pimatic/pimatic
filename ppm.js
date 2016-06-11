#!/usr/bin/env node
/*
  Modified version of https://github.com/npm/npm/blob/master/bin/npm-cli.js
  Copyright (c) npm, Inc. and Contributors
  Licensed on the terms of The Artistic License 2.0
  See https://github.com/npm/npm/blob/master/LICENSE
*/
var path = require("path");
var npm = require("npm");
var semver = require('semver');

if(!semver.satisfies(npm.version, '2.*')) {
  console.log("Error: npm version " + npm.version + " is not supported by ppm. "
    + "Please install npm v2 globally ('npm install -g npm@2') or locally in your "
    + "pimatic-app directory ('npm install npm@2'). See you again.");
  process.exit(1);
}

process.title = "ppm";

var log = require("npm/node_modules/npmlog");
log.pause() // will be unpaused when config is loaded.
log.info("it worked if it ends with", "ok");


var npmconf = require("npm/lib/config/core.js");
var errorHandler = require("npm/lib/utils/error-handler.js");

var configDefs = npmconf.defs;
var shorthands = configDefs.shorthands;
var types = configDefs.types;
var nopt = require("npm/node_modules/nopt");

// if npm is called as "npmg" or "npm_g", then
// run in global mode.
if (path.basename(process.argv[1]).slice(-1)  === "g") {
  process.argv.splice(1, 1, "npm", "-g")
}

log.verbose("cli", process.argv)

var conf = nopt(types, shorthands)
npm.argv = conf.argv.remain
if (npm.deref(npm.argv[0])) npm.command = npm.argv.shift()
else conf.usage = true


if (conf.version) {
  console.log(npm.version)
  return
}

if (conf.versions) {
  npm.command = "version"
  conf.usage = false
  npm.argv = []
}

log.info("using", "npm@%s", npm.version)
log.info("using", "node@%s", process.version)

process.on("uncaughtException", function(err){console.log(err.stack);})

if (conf.usage && npm.command !== "help") {
  npm.argv.unshift(npm.command)
  npm.command = "help"
}

// now actually fire up npm and run the command.
// this is how to use npm programmatically:
conf._exit = true
npm.load(conf, function (er) {
  if (er) return errorHandler(er)

  // we are patching install with out modified routine
  if (npm.command === 'install') {
    var install = require('./ppm/install.js');
    install(npm.argv, errorHandler);
    return;
  }
  npm.commands[npm.command](npm.argv, errorHandler)
});
