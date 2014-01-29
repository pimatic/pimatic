pimatic
=======

[![Build Status](https://travis-ci.org/pimatic/pimatic.png?branch=development)](https://travis-ci.org/pimatic/pimatic)
[![NPM version](https://badge.fury.io/js/pimatic.png)](http://badge.fury.io/js/pimatic)

pimatic is a home automation framework that runs on [node.js](http://nodejs.org). It provides a 
common extensible platform for home control and automation tasks.  

It defines several schemata for different home devices and sensors, so that all devices can be 
controled uniform and are presented in a common interface.

Automation tasks can be defined by rules in the form of "if this then that", where the "this" and 
the "that" part can be fully custimized by plugins. See [the rules section](#the-rules-section) for 
more details.

The mobile frontend plugin provieds a nice web frontend with a sensor overview, device control and
rule definition. The web interface is built using [express](http://expressjs.com) and 
[jQuery Mobile](http://jquerymobile.com/‎).

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
_Why not just using php with apache, nginx or C++?_
Because Node.js is fancy and cool and javaScript is the language of the internet of things. No, to be seriously: Because Node.js with its event loop, asynchronously and non-blocking programming model is well suited for home automation tasks. Have you ever tryed implementing a cron like job in php? In addition there are tons of easy to use [packages and libs](https://npmjs.org/).

_But the Raspberry Pi ist not very powerful, won't JavaScript be very slow?_ 
Yes and No, JavaScript is surely slower than C, but its getting faster and faster and runs very well on arm devices. Because disk access and network latency should be the real bottleneck of the pi, Node.js could perform well better than c++ because of its non blocking nature.

Installation
------------
First you need to install [node.js](http://nodejs.org) that comes with the package manager 
[npm](https://npmjs.org/). Then you can run

    mkdir pimatic-app
    npm install pimatic --prefix pimatic-app

to install the pimatic framework.

Configuration
-------------
I recommend to start with the default config:

    cd pimatic-app
    cp ./node_modules/pimatic/config_default.json ./config.json

The config is in the [json](https://en.wikipedia.org/wiki/JSON) format and currently includes five 
sections:

    { 
      "settings": { ... },
      "plugins": [ ... ],
      "devices": [ ... ],
      "rules": [ ... ]
    }

### The "settings"-section
The `"settings"`-section contains the configuration for the http- and https-server. You have 
to set `"username"` and `"password"` for the authentication or disable it. In the default config 
just the http-server is enabled and configurated to run on port 80.

See the [config-schema](http://www.pimatic.org/docs/config-schema.html) for more details and
all configuration options.

### The "plugins"-section
In the `"plugins"`-section you have to list all plugins to load in the form of

    { 
      "plugin": "plugin-name" 
    }

where `"plugin-name"` ist the name and directory of the plugin you want to load. All plugins are 
installed in the `node_modules` directory and prefixed with `pimatic-`. 

#### Available Plugins:

  * devices and sensors:
    * [pilight plugin](http://www.pimatic.org/docs/pimatic-pilight/)
    * [sispmctl plugin](http://www.pimatic.org/docs/pimatic-sispmctl/)
    * [gpio plugin](http://www.pimatic.org/docs/pimatic-gpio/)
    * [shell execute plugin](http://www.pimatic.org/docs/pimatic-shell-execute/)
  * frontend or api:
    * [mobile-frontend plugin](http://www.pimatic.org/docs/pimatic-mobile-frontend/)
    * [datalogger plugin](http://www.pimatic.org/docs/pimatic-datalogger/)
    * [filebrowser plugin](http://www.pimatic.org/docs/pimatic-filebrowser/)
    * [redirect plugin](http://www.pimatic.org/docs/pimatic-redirect/)
    * [rest-api plugin](http://www.pimatic.org/docs/pimatic-rest-api/)
  * rule predicates and actions:
    * [cron plugin](http://www.pimatic.org/docs/pimatic-cron/)
    * [ping plugin](http://www.pimatic.org/docs/pimatic-ping/)
    * [log-reader plugin](http://www.pimatic.org/docs/pimatic-log-reader/)
    * [shell execute plugin](http://www.pimatic.org/docs/pimatic-shell-execute/)

### The "devices"-section
The `"devices"`-section should contain all devices, you want to have registered in the 
framework. An actuator is typically provided by a plugin, so take a look at the desired plugin 
for more details about the configuration of your devices. A device configuration has the form

    { 
      "id": "light",
      "class": "SomeSwitch",
      "name": "Light in the kitchen",
      ...
    }

where the `"id"` should be unique, the `"name"` should be human readable description and `"class"`
determines the plugin and type of the device. 


### The "rules"-section
The `"rules"`-section can contain a list of rules in the form of:

    { 
      "id": "printerOff",
      "rule":  "if its 6pm then turn the printer off"
    }

where `"id"` should be a unique string and rule a string of the form "if ... then ...". 

Running
-------
The server can be started with 

    cd pimatic-app/node_modules
    sudo .bin/pimatic.js

To daemonize pimatic you can run:

    cd pimatic-app/node_modules
    sudo .bin/pimatic.js start

You can also use `status`, `stop`, `restart`.

###Install global

To make pimatic available global you can run:

    cd ./node_modules/pimatic
    sudo npm link

Then pimatic can be used with:

    sudo pimatic.js [start|stop|status|restart]

Documentation
-------------

pimatics source files are annotated with 
[literate programming](http://en.wikipedia.org/wiki/Literate_programming) style comments and docs. 
You can [browse the self generated documentation](http://www.pimatic.org/docs/) with the 
source code side by side.

Extensions and Hacking
----------------------
The framework is built to be extendable by plugins. If you have devices that are currently not 
supported please add a plugin for your devices. 
As well, if you have a nice Ideas for plugins or need support for specials actuators you are
welcome to create a issue or submit a patch.

For plugin development take a look at the
[plugin template](https://github.com/pimatic/pimatic-plugin-template).
