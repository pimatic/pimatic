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
[pilight-config-shema](pilight-config-shema.html)

Actuators are automatically added from the pilight-daemon config, when the connection is established. 