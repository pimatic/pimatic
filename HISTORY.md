# Release History

* 20190604, V0.9.49
    * Added blacklist mechanism to filter-out non-functional or obsolete plugins from list of 
      installable plugins
    * Optimization for Docker
      * Added support for using pm2-docker as an alternative to using the service daemon for docker containers
      * Added experimental install mode to perform sqlite3 installation and generation of JS files as 
        part of the docker image build
    * Updated to sqlite3@4.0.9 for node v12 and Raspbian Buster support 
    * Updated documentation reference
     
* 20190414, V0.9.48
    * Added config extension for Shutter position labels
    * Fixed creation of variables for new attributes on changed (edited) device
    * Fixed catch statement missing error parameter on device initialization
    * Updated dependencies
    
* 20190324, V0.9.47
    * Added minimal implementation for xAttributeOption displayFormat to support custom attribute 
      value formats with pimatic-mobile-frontend
    * Revised localization files, thanks @hvdwolf (nl.json)
    * Updated dependencies
    * Revised README
    
* 20190220, V0.9.46
    * Added module alias for 'i18n' to support plugins requiring it via pimatic env, thanks @madison5 for
      highlighting this issue with pimatic-fronius-solar 

* 20190213, V0.9.45
    * Upgraded to sqlite3@4.0.4 which is required to support node v10
    * Updated dependencies

* 20190128, V0.9.44
    * Migrated to lodash 4
    * Now using a derivation of i18n o work-around installation issues
    
* 20180626, V0.9.43
    * Added log output for Node.js and OpenSSL version on startup
    * Include id on "device not found" error, issue #1100
    * Added new functions: sign, trunc, diffDate, log
    * Replaced deprecated __defineGetter__ feature with Object.defineProperty() API	
    * Removed gittip badge as Gittip/Gratipay went out of business
