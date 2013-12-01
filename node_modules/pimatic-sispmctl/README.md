pimatic sispmctl plugin
=======================
Backend for the [SIS-PM Control for Linux aka sispmct](http://sispmctl.sourceforge.net/) 
application that can control GEMBIRD (m)SiS-PM device, witch are USB controled multiple socket.

Configuration
-------------
You can load the backend by editing your `config.json` to include:

    { 
       "plugin": "sispmctl"
    }

in the `backend` section. For all configuration options see 
[sisomctl-config-shema](sisomctl-config-shema.html)

Actuators can be added bei adding them to the `actuators` section in the config file.
Set the `class` attribute to `PilightOutlet`. For example:

    { 
      "id": "light",
      "class": "SispmctlSwitch", 
      "name": "Lamp",
      "outletId": 1 
    }

For actuator configuration options see the 
[actuator-config-shema.coffee](actuator-config-shema.html) file.