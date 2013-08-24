sweetpi-server
==============

sweetpi-server is a home automation server and framework that runs on [node.js](http://nodejs.org). It provied a simple web frontend using [express](http://expressjs.com) and [jQuery Mobile](jquerymobile.com/‎). It is built to run on the raspberry pi, but should be runnable on any device that can run node.js.

The includes a web frontend to control various actuators. 

Installation
------------
First you need to install [node.js](http://nodejs.org) with its package manager [npm](https://npmjs.org/). Then you can run

    npm install sweetpi-server

to install the sweetpi-server.

Configuration
-------------
I recommend to start with the default config:

    cp default_config.json config.json

The config is in the [json](https://en.wikipedia.org/wiki/JSON) format and currently includes four sections:

    { 
      "server": { ... },
      "frontends": [ ... ],
      "backends": [ ... ],
      "actuators": [ ... ]
    }

### "server"-section
The `"server"`-section contains the configuration for the http- and https-server. You have to set `"username"` and `"password"` for the authentication or disable it. In the default config just the http-server is enabled and configurated to run on port 80.

### "frontend"-section
In the `"frontends"`-section you have to list all frontends to load in the form of

    { 
      "module": "frontend-name" 
    }

where `"frontend-name"` ist the name and directory of the frontend you want to load. All frontends are in the `frontends` directory. Additional you can add frontend specific configuration properties. See the documantation of the frontend you want to load for details about them.

### "backend"-section
The `"backends"`-section should contain the backends to load. The form is the same like in the `frontend`-Section.  All backends are in the `backends` directory.

### "actuators"-section
The `"actuators"`-section should contain all actuators, you want to have registered in the framework. An actuator are typically provided by a backend, so take a look at the desired backend for more details about the configuration of your actuators. A actuator configuration has the form

    { 
      "id": "light",
      "class": "SomeSwitch",
      "name": "Light in the kitchen",
      ...
    }

where the `"id"` should be unique, the `"name"` should be human readable description and `"class"` determines the backend and type of the actuator. 

Running
-------
The server can be started with 

    node main.js`

or if you have [CoffeeScript](http://coffeescript.org/) globally installed, just run

  coffee sweetpi.coffee


Extensions and Hacking
----------------------
The framework is built to be extendable by frontends and backends. If you have devices that are currently not supported please fork the project and add a backend for your devices. 
As well, if you have a nice Ideas for frontends or need support for specials actuators you are welcome to create a issue or submit a patch.