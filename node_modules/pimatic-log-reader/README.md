pimatic log-reader plugin
=========================

Configutation:
--------------
Add your device to the config:

    { 
      "plugin": "log-reader",
      "logs": [
        {
          "file": "/var/log/gmediarender",
          "lines": [
            {
              "match": "TransportState: PLAYING",
              "predicate": "music starts"
            },
            {
              "match": "TransportState: STOPPED",
              "predicate": "music stops"
            }
          ]
        }
      ]
    }

Then you can use the predicates defined in your config.
