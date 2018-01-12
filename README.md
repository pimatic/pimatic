pimatic
=======

[![Build Status](https://travis-ci.org/pimatic/pimatic.png?branch=master)](https://travis-ci.org/pimatic/pimatic)
[![NPM version](https://badge.fury.io/js/pimatic.png)](http://badge.fury.io/js/pimatic)
[![Ready](https://badge.waffle.io/pimatic/pimatic.png?label=ready&title=Ready)](https://waffle.io/pimatic/pimatic)

pimatic is a home automation framework that runs on [node.js](http://nodejs.org). It provides a 
common extensible platform for home control and automation tasks.  

Read more at [pimatic.org](http://pimatic.org/) or visit the [forum](http://forum.pimatic.org).

[![Join the chat at https://gitter.im/pimatic/pimatic](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/pimatic/pimatic?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Screenshots
-----------
[![Screenshot 1][screen1_thumb]](http://www.pimatic.org/screens/screen1.png) 
[![Screenshot 2][screen2_thumb]](http://www.pimatic.org/screens/screen2.png) 
[![Screenshot 3][screen3_thumb]](http://www.pimatic.org/screens/screen3.png) 
[![Screenshot 4][screen4_thumb]](http://www.pimatic.org/screens/screen4.png)

[screen1_thumb]: http://www.pimatic.org/screens/screen1_thumb.png?v=1
[screen2_thumb]: http://www.pimatic.org/screens/screen2_thumb.png?v=1
[screen3_thumb]: http://www.pimatic.org/screens/screen3_thumb.png?v=1
[screen4_thumb]: http://www.pimatic.org/screens/screen4_thumb.png?v=1

Getting Started
------------

[Install instruction](http://pimatic.org/guide/getting-started/installation/) can be found 
on [pimatic.org](http://pimatic.org/). If you need any help, [ask at the forum](http://forum.pimatic.org).

Donation
--------

Happy with pimatic and using it every day? Consider a donation to support development and keeping the website and forum up: 
[![PayPal donate button](http://img.shields.io/paypal/donate.png?color=blue)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=KCVVRY4243JS6 "Donate once-off to this project using Paypal")

We promise, that pimatic will always be free to use and its code be open sourced.

Get Involved
-------------

pimatic is your opportunity to [contribute to a growing OpenSource-Project](https://github.com/pimatic/pimatic/issues/223).

Architecture Overview
---------------------

    +-------------------------------------------+
    | mobile-  | rest- | cron | homeduino | ... |  Plugins (Views, Device-/Preidcates-
    | frontend | api   |      |           |     |  Action-Provider, Services)
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
As well, if you have nice ideas for plugins or need support for special devices you are
welcome to create an issue or submit a patch.

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

