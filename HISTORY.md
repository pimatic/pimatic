# Release History

* 20190906, V0.9.53
    * Fixed bug: Skip log messages which do not contain meta tags and timeStamp
    * Cast null values as part of variable expression to avoid exception "expected ... to have numeric value"
      in case of uninitialized attributes on startup
    * Changed cassert dependency to work-around permission issue with npm link
    * Added Systemd service wrapper for pimatic. The Initd service wrapper is now deprecated. See also
      https://pimatic.teamemo.com/Guide/Autostarting
      
* 20190823, V0.9.52
    * Fixed bug in variable expression handler introduced by earlier refactoring
    
* 20190822, V0.9.51
    * Added "enableActiveButton" property to ButtonsDevice configuration schema to control 
      display active button feature
    * Added support for unix sockets, PR #1124, thanks @Unkn0wn-MDCLXIV
      
* 20190702, V0.9.50
    * Dependency fixture for cassert package
    * Build includes bundledDependencies as several users had issues with the unbundled
      build v0.9.49
      
* 20190627, V0.9.49
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
