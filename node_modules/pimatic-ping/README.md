pimatic ping plugin
===================

Provides Sensors for you wifi device, so actions can be triggered
if a wifi device is (or is not) present.

Providided predicates
---------------------
Add your device to the backend config:

    { 
      "module": "device-presents",
      "devices": [
        {
          "id": "my-phone",
          "name": "my smartphone",
          "host": "192.168.1.26",
          "delay": 5000
        }
      ]
    }

Then you can use the predicates:

 * `"my smartphone is present"` or `"my-phone is present"`
 * `"my smartphone is not present"` or `"my-phone is not present"`
