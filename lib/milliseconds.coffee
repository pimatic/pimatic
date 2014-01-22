###
Milliseconds Helper
===================

Helpers for time to milliseconds parsing. 
###

###
From visionmedia / mocha converted to coffee-script
Orginal file: https://github.com/visionmedia/mocha/blob/master/lib/ms.js

License for this file:

(The MIT License)

Copyright (c) 2011-2013 TJ Holowaychuk <tj@vision-media.ca>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
###

s = 1000
m = s * 60
h = m * 60
d = h * 24
y = d * 365.25

#Parse or format the given `val`.
parse = (str) ->
  match = /^((?:\d+)?\.?\d+) *(ms|seconds?|s|minutes?|m|hours?|h|days?|d|years?|y)?$/i.exec(str)
  return unless match
  n = parseFloat(match[1])
  type = (match[2] or "ms").toLowerCase()
  switch type
    when "years", "year", "y"
      n * y
    when "days", "day", "d"
      n * d
    when "hours", "hour", "h"
      n * h
    when "minutes", "minute", "m"
      n * m
    when "seconds", "second", "s"
      n * s
    when "ms"
      n


# Short format for `ms`.
shortFormat = (ms) ->
  if ms >= d then return Math.round(ms / d) + "d"  
  if ms >= h then return Math.round(ms / h) + "h"  
  if ms >= m then return Math.round(ms / m) + "m"  
  if ms >= s then return Math.round(ms / s) + "s"  
  ms + "ms"


# Long format for `ms`.
longFormat = (ms) ->
  plural(ms, d, "day") or 
  plural(ms, h, "hour") or 
  plural(ms, m, "minute") or 
  plural(ms, s, "second") or 
  ms + " ms"

# Pluralization helper.
plural = (ms, n, name) ->
  if ms < n then return  
  if ms < n * 1.5 then return Math.floor(ms / n) + " " + name  
  Math.ceil(ms / n) + " " + name + "s"

module.exports.parse = parse
module.exports.shortFormat = shortFormat
module.exports.longFormat = longFormat