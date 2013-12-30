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
[sispmctl-config-shema](sispmctl-config-shema.html)

Actuators can be added bei adding them to the `actuators` section in the config file.
Set the `class` attribute to `SispmctlSwitch`. For example:

    { 
      "id": "light",
      "class": "SispmctlSwitch", 
      "name": "Lamp",
      "outletUnit": 1 
    }

For actuator configuration options see the 
[actuator-config-shema](actuator-config-shema.html) file.