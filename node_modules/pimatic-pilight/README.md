pimatic pilight plugin
======================

Backend for the [pilight library](https://github.com/pilight/pilight) to control 433Mhz switches 
and dimmers and get informations from 433Mhz weather stations. See the project page for a list of 
supported devices.

Configuration
-------------
You can load the backend by editing your `config.json` to include:

    { 
       "plugin": "pilight"
    }

in the `backend` section. For all configuration options see 
[backend-config-shema](backend-config-shema.html)

Actuators can be added bei adding them to the `actuators` section in the config file.
Set the `class` attribute to `PilightOutlet`. For example:

    { 
      "id": "light",
      "class": "PilightSwitch", 
      "name": "Lamp",
      "outletUnit": 0,
      "outletId": 123456 
    }

For actuator configuration options see the 
[actuator-config-shema.coffee](actuator-config-shema.html) file.