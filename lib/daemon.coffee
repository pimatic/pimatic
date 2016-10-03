###
#Daemonizer

Orginal from [node-init](https://github.com/frodwith/node-init/blob/master/init.coffee)
modified by Oliver Schneider.

Copyright (c) 2011 Paul Driver

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
###

fs = require 'fs'
daemon = require 'daemon'
stream = require 'logrotate-stream'

exports.printStatus = (st) ->
  if st.pid
    console.log 'Process running with pid %d.', st.pid
    process.exit 0

  else if st.exists
    console.log 'Pidfile exists, but process is dead.'
    process.exit 1
  else
    console.log 'Not running.'
    process.exit 3

exports.status = (pidfile, cb = exports.printStatus) ->
  fs.readFile pidfile, 'utf8', (err, data) ->
    if err
      cb exists: err.code isnt 'ENOENT'
    else if match = /^\d+/.exec(data)
      pid = parseInt match[0]
      try
        process.kill pid, 0
        cb pid: pid
      catch e
        cb exists: true
    else
      cb exists: true

exports.startSucceeded = (pid) ->
  if pid
    console.log 'Process already running with pid %d.', pid
  else
    console.log 'Started.'

exports.startFailed = (err) ->
  console.log err
  process.exit 1

exports.start = ({ pidfile, logfile, run, success, failure }) ->
  success or= exports.startSucceeded
  failure or= exports.startFailed
  logfile or= '/dev/null'

  start = (err) ->
    return failure(err) if err
    if process.env['PIMATIC_DAEMONIZED']? 
      # pipe strams to lofile:
      logStream = stream(file: logfile, size: '1m', keep: 3)
      process.stdout.writeOut = process.stdout.write
      process.stderr.writeOut = process.stderr.write
      process.stdout.write = (string) -> logStream.write string
      process.stderr.write = (string) -> logStream.write string
      process.logStream = logStream

      # write the pidfile
      fs.writeFile pidfile, process.pid, (err) ->
        return failure(err) if err
        run()
    else 
      #Restart as daemon:
      process.env['PIMATIC_DAEMONIZED'] = true
      daemon.daemon process.argv[1], process.argv[2..], {cwd: process.cwd()}
      success()
      
  exports.status pidfile, (st) ->
    if st.pid
      success st.pid, true
    else if st.exists
      fs.unlink pidfile, start
    else
      start()


exports.stopped = (killed) ->
  if killed
    console.log 'Stopped.'
  else
    console.log 'Not running.'
  process.exit 0

exports.hardKiller = () ->
  (pid, cb) ->
    checkInterval = 1000
    timeout = 10000
    signals = ['TERM', 'QUIT', 'KILL']
    tryKill = (time)->
      sig = "SIG#{signals[0]}"
      try
        if time is 0
          console.log "Sending #{sig} to pimatic(#{pid}), waiting for process exit..."
          # throws when the process no longer exists
          process.kill pid, sig
        else if time >= timeout
          console.log "Process didn't shutdown in time, sending signal #{sig} to pimatic(#{pid}), 
            waiting for process exit..."
          # throws when the process no longer exists
          process.kill pid, sig
          signals.shift() if signals.length > 1
          time = 0
        else
          # test if process exists
          process.kill pid, 0
        setTimeout (-> tryKill(time + checkInterval) ), checkInterval
      catch e
        killed = e.code is 'ESRCH'
          # throws an error if the process was killed
        unless killed
          console.error "Couldn't kill process, error: #{e.message}"
        cb(killed)

    tryKill(0)

exports.softKiller = (timeout = 2000) ->
  (pid, cb) ->
    sig = "SIGTERM"
    tryKill = ->
      try
        # throws when the process no longer exists
        process.kill pid, sig
        console.log "Waiting for pid " + pid
        sig = 0 if sig != 0
        first = false
        setTimeout tryKill, timeout
      catch e
        cb(sig == 0)
    tryKill()

exports.stop = (pidfile, cb = exports.stopped, killer = exports.hardKiller()) ->
  exports.status pidfile, ({pid}) ->
    if pid
      killer pid, (killed) ->
        fs.unlink pidfile, -> cb(killed)
    else
      cb false

exports.simple = ({pidfile, logfile, command, run, killer}) ->
  command or= process.argv[2]
  killer or= null
  start = -> exports.start { pidfile, logfile, run }
  switch command
    when 'start'  then start()
    when 'stop'   then exports.stop pidfile, null, killer
    when 'status' then exports.status pidfile
    when 'restart', 'force-reload'
      exports.stop pidfile, start, killer
    when 'try-restart'
      exports.stop pidfile, (killed) ->
        if killed
          exports.start { pidfile, logfile, run }
        else
          console.log 'Not running.'
          process.exit 1
    else
      console.log 'Command must be one of: ' +
        'start|stop|status|restart|force-reload|try-restart'
      process.exit 1