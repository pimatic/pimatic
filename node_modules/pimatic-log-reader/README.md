pimatic log-reader plugin
=========================

The log-reader let you define sensors based on log entries in log files of other programs.
So you can trigger rules besed on log entries. See the example-Section for more details.

Configutation:
--------------

Add the plugin to to plugins-Array in the config.json file:

    { 
      "plugin": "log-reader"
    }

Then add a sensor for your log-entries to the sensors section:

    {
      "id": "some-id",
      "name": "some name",
      "class": "LogWatcher",
      "file": "/var/log/some-logfile",
      "states": [
        "some-state"
      ],
      "lines": [
        {
          "match": "some log entry 1",
          "predicate": "entry 1",
          "some-state": "1" 
        },
        {
          "match": "some log entry 2",
          "predicate": "entry 2",
          "some-state": "2"
        }
      ]
    }


Then you can use the predicates defined in your config.

Examples:
---------

##turn a speacker on and off when a music player starts or stops playing:

Assuming that you are using [gmediarender](https://github.com/hzeller/gmrender-resurrect) and the 
log is written to "/var/log/gmediarender". Then define following sensor:

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

and add the following rules for a existing speaker actuator:

    if music starts then turn the speacker on

    if music stops then turn the speacker off

##turn the printer on when you start printing:

Define the following sensor:

    {
      "id": "printer-status",
      "name": "Printer Log",
      "class": "LogWatcher",
      "file": "/var/log/cups/page_log",
      "states": [],
      "lines": [
        {
          "match": "psc_1100",
          "predicate": "new print job"
        }
      ]
    }

and define the rule:

    if new print job then turn printer on