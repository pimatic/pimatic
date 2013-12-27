pimatic log-reader plugin
=========================

Configutation:
--------------
Add your device to the config:

    { 
      "plugin": "log-reader"
    }

Then add a sensor for your device to the sensors section:

    {
      "id": "gmediarender-status",
      "name": "Music Player",
      "class": "LogWatcher",
      "file": "/var/log/gmediarender",
      "states": [
        "music-state"
      ],
      "lines": [
        {
          "match": "TransportState: PLAYING",
          "predicate": "music starts",
          "music-state": "playing" 
        },
        {
          "match": "TransportState: STOPPED",
          "predicate": "music stops",
          "music-state": "stopped"
        }
      ]
    }



Then you can use the predicates defined in your config.
