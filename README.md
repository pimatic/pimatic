pimatic
==============

pimatic is a home automation framework that runs on [node.js](http://nodejs.org). It provides a 
common extensible platform for home control and automation tasks.  

It defines several shemata for different home devices and sensors, so that all devices can be 
controled uniform and are presented in a common interface.

Automation tasks can be defined by rules in the form of "if this then that", where the "this" and 
the "that" part can be fully custimized by plugins. See [the rules section](#the-rules-section) for 
more details.

The mobile frontend plugin provieds a nice web frontend with a sensor overview, device control and
rule definition. The web interface is built using [express](http://expressjs.com) and 
[jQuery Mobile](http://jquerymobile.com/‎).

Screenshots
-----------
[![Screenshot 1][screen1_thumb]](http://www.sweetpi.de/pimatic/screens/screen1.png) 
[![Screenshot 2][screen2_thumb]](http://www.sweetpi.de/pimatic/screens/screen2.png) 
[![Screenshot 3][screen3_thumb]](http://www.sweetpi.de/pimatic/screens/screen3.png) 
[![Screenshot 4][screen4_thumb]](http://www.sweetpi.de/pimatic/screens/screen4.png)

[screen1_thumb]: http://www.sweetpi.de/pimatic/screens/screen1_thumb.png
[screen2_thumb]: http://www.sweetpi.de/pimatic/screens/screen2_thumb.png
[screen3_thumb]: http://www.sweetpi.de/pimatic/screens/screen3_thumb.png
[screen4_thumb]: http://www.sweetpi.de/pimatic/screens/screen4_thumb.png


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
      "actuators": [ ... ],
      "sensors": [ ... ],
      "rules": [ ... ]
    }

### The "settings"-section
The `"settings"`-section contains the configuration for the http- and https-server. You have 
to set `"username"` and `"password"` for the authentication or disable it. In the default config 
just the http-server is enabled and configurated to run on port 80.

See the [config-shema](http://sweetpi.de/pimatic/docs/config-shema.html) for more details and
all configuration options.

### The "plugins"-section
In the `"plugins"`-section you have to list all plugins to load in the form of

    { 
      "plugin": "plugin-name" 
    }

where `"plugin-name"` ist the name and directory of the plugin you want to load. All plugins are in 
the `node_modules` directory and there prefixed with `pimatic-`. 

#### Available Plugins:

  * devices and sensors:
    * [pilight plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-pilight/README.html)
    * [sispmctl plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-sispmctl/README.html)
    * [gpio plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-gpio/README.html)
  * frontend or api:
    * [mobile-frontend plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-mobile-frontend/README.html)
    * [filebrowser plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-filebrowser/README.html)
    * [redirect plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-redirect/README.html)
    * [rest-api plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-rest-api/README.html)
    * [speak-api plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-speak-api/README.html)  
  * rule predicates:
    * [cron plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-cron/README.html)
    * [ping plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-ping/README.html)
    * [log-reader plugin](http://sweetpi.de/pimatic/docs/node_modules/pimatic-log-reader/README.html)

### The "actuators"-section
The `"actuators"`-section should contain all actuators, you want to have registered in the 
framework. An actuator is typically provided by a plugin, so take a look at the desired plugin 
for more details about the configuration of your actuators. A actuator configuration has the form

    { 
      "id": "light",
      "class": "SomeSwitch",
      "name": "Light in the kitchen",
      ...
    }

where the `"id"` should be unique, the `"name"` should be human readable description and `"class"`
determines the plugin and type of the actuator. 

### The "sensor"-section
The `"sensor"`-section should contain all sensors, you want to have registered in the framework. 
A sensor is typically provided by a plugin, so take a look at the desired plugin for more details 
about the configuration of your sensor. A sensor configuration has the form

    { 
      "id": "temperature",
      "class": "SomeSensor",
      "name": "Temperature in the kitchen",
      ...
    }

where the `"id"` should be unique, the `"name"` should be human readable description and `"class"` 
determines the plugin and type of the sensor. 


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

    cd pimatic-app
    sudo ./node_modules/pimatic/main.js


Extensions and Hacking
----------------------
The framework is built to be extendable by plugins. If you have devices that are currently not supported please add a plugin for your devices. 
As well, if you have a nice Ideas for plugins or need support for specials actuators you are welcome to create a issue or submit a patch.