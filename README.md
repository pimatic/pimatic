sweetpi-server
==============

sweetpi-server is a home automation server and framework built on nodejs and express 
to control various devices (actors). It can be run on the raspberry pi.

Installation
------------
```
  npm install sweetpi-server
  cp default_config.coffee config.coffee
```
Edit the `config.coffee` file with your favorit editor and then start the server with `node main.js` or `coffee sweetpi.coffee`.

Extensions
----------
The framework is built to be extendet by modules. A module can ba a `Frontend` or a `Backend`. 

###Frontends
A frontend is typically a interface for other scripts, software or the user to interact with the server. See the `frontends` directory for more informations.

###Backends
A backend typically provides actors that can exectute actions. See the `backends` directory for more informations.
