pimatic mobile-frontend plugin
======================

Provides a [jQuery mobile](http://jquerymobile.com/) page, witch let you control
your actuators, display sensor values and let you add and edit rules. 

Example config:
---------------

    {
      "plugin": "mobile-frontend",
      "items": [
        {
          "type": "actuator",
          "id": "my-tv"
        },
        {
          "type": "actuator",
          "id": "my-work-lampe"
        },
        {
          "type": "sensor",
          "id": "my-temperature-sensor"
        }
      ]
    }