pimatic
==============

pimatic is a home automation server and framework that runs on [node.js](http://nodejs.org). It provied a simple web frontend using [express](http://expressjs.com) and [jQuery Mobile](jquerymobile.com/‎). It is built to run on the raspberry pi, but should be runnable on any device that can run node.js.

Installation
------------
First you need to install [node.js](http://nodejs.org) that comes with the package manager [npm](https://npmjs.org/). Then you can run

    npm install pimatic

to install the pimatic.

Configuration
-------------
I recommend to start with the default config:

    cd node_modules/pimatic
    cp default_config.json config.json

The config is in the [json](https://en.wikipedia.org/wiki/JSON) format and currently includes four sections:

    { 
      "server": { ... },
      "plugins": [ ... ],
      "actuators": [ ... ],
      "rules": []
    }

### The "server"-section
The `"server"`-section contains the configuration for the http- and https-server. You have to set `"username"` and `"password"` for the authentication or disable it. In the default config just the http-server is enabled and configurated to run on port 80.

### The "plugins"-section
In the `"plugins"`-section you have to list all plugins to load in the form of

    { 
      "plugin": "plugin-name" 
    }

where `"plugin-name"` ist the name and directory of the plugin you want to load. All plugins are in the `node_modules` directory and there prefixed with `pimatic-`. 

### The "actuators"-section
The `"actuators"`-section should contain all actuators, you want to have registered in the framework. An actuator are typically provided by a backend, so take a look at the desired backend for more details about the configuration of your actuators. A actuator configuration has the form

    { 
      "id": "light",
      "class": "SomeSwitch",
      "name": "Light in the kitchen",
      ...
    }

where the `"id"` should be unique, the `"name"` should be human readable description and `"class"` determines the backend and type of the actuator. 

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

    cd node_modules/pimatic
    sudo ./main.js

or if you have [CoffeeScript](http://coffeescript.org/) globally installed, you can run

    cd node_modules/pimatic
    sudo coffee pimatic.coffee

Extensions and Hacking
----------------------
The framework is built to be extendable by frontends and backends. If you have devices that are currently not supported please fork the project and add a backend for your devices. 
As well, if you have a nice Ideas for frontends or need support for specials actuators you are welcome to create a issue or submit a patch.