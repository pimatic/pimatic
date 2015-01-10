pimatic
=======

[![Build Status](https://travis-ci.org/pimatic/pimatic.png?branch=master)](https://travis-ci.org/pimatic/pimatic)
[![NPM version](https://badge.fury.io/js/pimatic.png)](http://badge.fury.io/js/pimatic)
[![Ready](https://badge.waffle.io/pimatic/pimatic.png?label=ready&title=Ready)](https://waffle.io/pimatic/pimatic)
[![Gittip donate button](http://img.shields.io/gittip/sweetpi.png)](https://www.gittip.com/sweetpi/ "Donate weekly to this project using Gittip")
[![PayPal donate button](http://img.shields.io/paypal/donate.png?color=blue)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=KCVVRY4243JS6 "Donate once-off to this project using Paypal")

pimatic is a home automation framework that runs on [node.js](http://nodejs.org). It provides a 
common extensible platform for home control and automation tasks.  

Read more at [pimatic.org](http://pimatic.org/).

Screenshots
-----------
[![Screenshot 1][screen1_thumb]](http://www.pimatic.org/screens/screen1.png) 
[![Screenshot 2][screen2_thumb]](http://www.pimatic.org/screens/screen2.png) 
[![Screenshot 3][screen3_thumb]](http://www.pimatic.org/screens/screen3.png) 
[![Screenshot 4][screen4_thumb]](http://www.pimatic.org/screens/screen4.png)

[screen1_thumb]: http://www.pimatic.org/screens/screen1_thumb.png
[screen2_thumb]: http://www.pimatic.org/screens/screen2_thumb.png
[screen3_thumb]: http://www.pimatic.org/screens/screen3_thumb.png
[screen4_thumb]: http://www.pimatic.org/screens/screen4_thumb.png

Motivation - Why Node.js?
------------
__Why not just using php with apache, nginx or C++?__  
Because Node.js is fancy and cool and javaScript is the language of the internet of things. No, to be seriously: Because Node.js with its event loop, asynchronously and non-blocking programming model is well suited for home automation tasks. Have you ever tryed implementing a cron like job in php? In addition there are tons of easy to use [packages and libs](https://npmjs.org/).

__But the Raspberry Pi ist not very powerful, won't JavaScript be very slow?__  
Yes and No, JavaScript is surely slower than C, but its getting faster and faster and runs very well on arm devices. Because disk access and network latency should be the real bottleneck of the pi, Node.js could perform well better than c++ because of its non blocking nature.

Getting Started
------------

[Install instuction](http://pimatic.org/guide/getting-started/installation/) can be found 
on [pimatic.org](http://pimatic.org/).

Get Involved
-------------

pimatic is your opportunity to [contribute to a growing OpenSource-Project](https://github.com/pimatic/pimatic/issues/223).

Architecture Overview
---------------------

    +-------------------------------------------+
    | mobile-  | rest- | cron | pilight   | ... |  Plugins (Views, Device-/Preidcates-
    | frontend | api   |      | (adapter) |     |  Action-Provider, Services)
    |-------------------------------------------|
    | pimatic (framework)                       |  Framework
    |-------------------------------------------|
    | rule   | device    | (core)     | (core)  |  Model
    | system | schemata  | predicates | actions |
    |-------------------------------------------|
    | node.js (non-blocking, async IO,          |  Low-Level Infrastructure
    | event-loop, v8)                           |
    +-------------------------------------------+


Extensions and Hacking
----------------------
The framework is built to be extendable by plugins. If you have devices that are currently not 
supported please add a plugin for your devices. 
As well, if you have a nice Ideas for plugins or need support for specials devices you are
welcome to create a issue or submit a patch.

For plugin development take a look at the 
[development guide](http://pimatic.org/guide/development/required-skills-readings/) and
[plugin template](https://github.com/pimatic/pimatic-plugin-template).

Feel free to ask development questions at the 
[plugin template repository](https://github.com/sweetpi/pimatic-plugin-template/issues).


Copyright / License
-------------------

    Copyright (C) 2014 Oliver Schneider <oliverschneider89+sweetpi@gmail.com>


    pimatic is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    pimatic is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with pimatic.  If not, see <http://www.gnu.org/licenses/>.

