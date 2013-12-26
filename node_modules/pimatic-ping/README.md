pimatic ping plugin
===================

Provides Sensors for you wifi device, so actions can be triggered
if a wifi device is (or is not) present.

Providided predicates
---------------------
Add the plugin to the plugin section:

    { 
      "plugin": "ping"
    }

Then add a sensor for your device to the sensors section:

    {
      "id": "my-phone",
      "name": "my smartphone",
      "class": "PingPresents",
      "host": "192.168.1.26",
      "delay": 5000
    }

Then you can use the predicates:

 * `"my smartphone is present"` or `"my-phone is present"`
 * `"my smartphone is not present"` or `"my-phone is not present"`
