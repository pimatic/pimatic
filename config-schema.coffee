# #Configuration options 
# Lists all configuration options for the pimatic framework itself.
# For an example `config.json` file see the `config_default.json` file.
module.exports = {
  title: "pimatic config"
  type: "object"
  properties:
    settings:
      type: "object"
      properties:
        locale:
          description: "The default language"
          type: "string"
          enum: ['en', 'de', "es", "nl", "fr", "ru"]
          default: "en"
        debug:
          description: "Turn on debug checks. Set the logLevel to debug to additional outputs"
          type: "boolean"
          default: false
        authentication:
          type: "object"
          properties:
            enabled:
              description: "Disable http-basic-authentication"
              type: "boolean"
              default: true
            secret:
              description: "Secret string used for cookie signing. Should be kept secret! If it 
              is not set, then a secret string will be generated for you, at first start. The 
              secret string must be at least 32 characters long.
              "
              secret: yes
            loginTime:
              description: """The time in milliseconds to keep the session cookie if rememberMe is 
              checked. If 0 then the cookie will be deleted on browser close. """
              type: "integer"
              default: 10 * 365 * 24 * 60 * 60 * 1000 #ten years
          required: false
        logLevel:
          description: "The log level: debug, info, warn, error" 
          type: "string"
          default: "info"
        httpServer:
          type: "object"
          properties:
            enabled: 
              description: "Should the HTTP-server be started"
              type: "boolean"
              default: true
            port:
              description: "The port of the HTTP-server"
              type: "integer"
              format: "port"
              default: 80
              minimum: 0
            hostname:
              description: "The hostname of the HTTP-server"
              type: "string"
              default: "" # If is empty then listen to all ip4 addresses
            socket:
              description: "The UNIX Socket of the HTTP-server"
              type: "string"
              default: "" # If empty use hostname + port instead
        httpsServer:
          type: "object"
          properties:
            enabled: 
              description: "Should the HTTPS-server be started"
              type: "boolean"
              default: false
            port:
              description: "The port of the HTTPS-server"
              type: "integer"
              format: "port"
              default: 443
              minimum: 0
            hostname:
              description: "The hostname of the HTTPS-server"
              type: "string"
              default: "" # If is empty then listen to all ip4Addresses
            ###
            Download https://raw.githubusercontent.com/pimatic/pimatic/master/install/ssl-setup
            and run ssl-setup in you pimatic-app dir to generate the necessary key and certificate 
            files:
            
                wget https://raw.githubusercontent.com/pimatic/pimatic/master/install/ssl-setup
                chmod +x ssl-setup
                ./ssl-setup

            ###
            keyFile:
              description: "Private-Key file"
              type: "string"
              default: "ca/pimatic-ssl/private/privkey.pem"
            certFile:
              description: "Public certification file in pem-format"
              type: "string"
              default: "ca/pimatic-ssl/public/cert.pem"
            rootCertFile:
              description: "The public root certificate file of your own CA if you are using a 
              self signed certificate. This is optional. It's just for the frontend, so that it 
              can provide a link to the the root certificate for easy importing in mobile devices.
              "
              type: "string"
              default: "ca/certs/cacert.crt"
          required: false
        cors:
          type: "object"
          required: false
          properties:
            allowedOrigin:
              description: """The origin allowed for cross-origin accesses.
                    The item "*" is used to accept all origins.
                    The empty string is used to deny all cross-origin accesses.
                    """
              type: "string"
              default: ""
        database:
          type: "object"
          properties:
            client: 
              description: "The database client to use"
              type: "string"
              enum: ["sqlite3", "mysql", "pg"]
              default: "sqlite3"
            ###
            The connection setting depends on database client. Some examples:
            __sqlite3:__

                {
                  filename: "pimatic-database.sqlite"
                }

            __mysql:__

                {
                  host     : '127.0.0.1',
                  user     : 'your_database_user',
                  password : 'your_database_password',
                  database : 'myapp_test'
                }
            ###
            connection:
              description: "The connection settings for the database client"
              type: "object"
              default: {
                filename: "pimatic-database.sqlite"
              }
            deviceAttributeLogging:
              description: """
                Defines time constraints on how attribute value changes of logged devices shall
                be kept in the database. Constraints will be evaluated sequentially where a
                subsequent constraint may override the previous one. A constraint can be
                defined by device id, attribute name, and attribute type. See also
                <a href='https://forum.pimatic.org/topic/44/database-configuration-howto'>
                Database configuration howto</a>
              """
              type: "array"
              default: [ 
                { 
                  deviceId: '*', attributeName: '*', type: "*", 
                  interval: "0", expire: '7d' 
                }
                { 
                  deviceId: '*', attributeName: '*', type: "continuous", 
                  interval: "5min", expire: '7d'
                }
                { 
                  deviceId: '*', attributeName: 'temperature', type: "number", 
                  expire: '1y' 
                }
                { 
                  deviceId: '*', attributeName: 'humidity', type: "number", 
                  expire: '1y' 
                } 
              ]
              items:
                type: "object"
                properties:
                  deviceId:
                    description: """
                      The deviceId of the logged device or "*" for all devices in the matching
                      context
                    """
                    type: "string"
                  attributeName:
                    description: """
                      The name of the attribute or "*" for all attributes in the matching
                      context
                    """
                    type: "string"
                  type:
                    description: """
                      The type of the attribute mapping, one of: "number", "string", "boolean",
                      "date", "discrete", "continuous", "*". The default, "*" is used for all
                      applicable attribute types in the matching context
                    """
                    type: "string"
                    default: "*"
                  interval:
                    description: """
                      A time duration constraint on the minmum time interval between attribute
                      value changes stored in database. If absent all attribute value changes will
                      stored in the database. The duration is provided in miliseconds if no unit
                      is provided. Supported units are: ms, second, seconds, s, minute, minutes,
                      m, hour, hours, h, day, days, d, year, years, y
                    """
                    type: "string"
                    required: false
                  expire:
                    description: """
                      A time duration constraint on how long attribute values shall be kept in the
                      database. The duration is provided in miliseconds if no unit is provided.
                      Supported units are: ms, second, seconds, s, minute, minutes, m, hour, hours,
                      h, day, days, d, year, years, y
                    """
                    type: "string"
                    required: false
            messageLogging:
              description: "Time to keep logged messages in database"
              type: "array"
              default: [ 
                { level: '*', tags: [], expire: '7d' }
                { level: 'debug', tags: [], expire: '0' }
              ]
            deleteExpiredInterval:
              description: "Interval for deleting expired entries from the database"
              type: "string"
              default: "2h"
            diskSyncInterval:
              description: "
                Interval for writing logged entries to disk. If this value is smaller than 
                the deleteExpiredInterval setting, then the value of this setting is used 
                instead. Should be a multiple of deleteExpiredInterval.
                "
              type: "string"
              default: "4h"
            debug: 
              description: "Enable to show database queries and some additional outputs"
              type: "boolean"
              default: false
        gui:
          type: "object"
          properties:
            hideRuleName: 
              description: "Don't show the name of rules on the rules page"
              type: "boolean"
              default: false
            hideRuleText: 
              description: "Don't show the text of rules on the rules page"
              type: "boolean"
              default: false
            demo:
              doc: """Show edit pages also if the user has no permissions, 
              like at demo.pimatic.org:8080
              """
              type: "boolean"
              default: false
          required: false
        defaultMaxListeners:
          description: """
          The number of listeners which can be registered
          for any single event (soft limit)
          """
          type: "number"
          default: 200
    pages:
      description: "Array of GUI pages"
      type: "array"
      default: []
      items:
        type: "object"
        properties:
          id:
            type: "string"
          name:
            type: "string"
          allowedRoles:
            description: """
            The roles allowed for accessing the page. If absent
            roles are granted access.
            """
            type: "array"
            required: false
          devices:
            type: "array"
            default: []
            items:
              type: "object"
              properties:
                deviceId:
                  type: "string"
    groups:
      description: "Array of groups"
      type: "array"
      default: []
      items:
        type: "object"
        properties:
          id:
            type: "string"
          name:
            type: "string"
          devices:
            type: "array"
            default: []
            items:
              type: "string"
          rules:
            type: "array"
            default: []
            items:
              type: "string"
          variables:
            type: "array"
            default: []
            items:
              type: "string"
    plugins:
      description: "Array of plugins to load"
      type: "array"
      default: []
      items:
        type: "object"
        properties:
          plugin:
            type: "string"
        additionalProperties: true
    devices:
      description: "Array of device definitions"
      type: "array"
      default: []
      items:
        type: "object"
        properties:
          id:
            type: "string"
          name:
            type: "string"
          class:
            type: "string"
        additionalProperties: true
    rules:
      description: "Array of rules"
      type: "array"
      default: []
      items:
        type: "object"
        properties:
          id:
            type: "string"
          name:
            type: "string"
          rule:
            type: "string"
          active:
            type: "boolean"
          logging:
            type: "boolean"
    variables:
      description: "Array of variables"
      type: "array"
      default: []
      items:
        anyOf: [
          {
            type: "object"
            properties:
              name:
                type: "string"
              value:
                type: "string"
              unit:
                type: "string"
          }, 
          {
            type: "object"
            properties:
              name:
                type: "string"
              expression:
                type: "string"
              unit:
                type: "string"
          }
        ]
    users:
      description: "Array of users"
      type: "array"
      default: [
        {
          username: "admin"
          password: ""
          role: "admin"         
        }
      ]
      items:
        type: "object"
        properties:
          username:
            description: "The login name of the user"
            type: "string"
          password:
            description: "The password of the user"
            type: "string"
            secret: yes
          role:
            description: "The role of the user"
            type: "string"
    roles:
      description: "Array of user roles"
      type: "array"
      default: [
        {
          name: "admin"
          permissions:
            pages: "write"
            rules: "write"
            variables: "write"
            messages: "write"
            events: "write"
            devices: "write"
            groups: "write"
            plugins: "write"
            updates: "write"
            config: "write"
            controlDevices: true
            restart: true
        },
        {
          name: "resident"
          permissions:
            pages: "read"
            rules: "read"
            variables: "read"
            messages: "read"
            events: "read"
            devices: "none"
            groups: "none"
            plugins: "none"
            updates: "none"
            config: "none"
            controlDevices: true
            restart: false
        }
      ]   
      items:
        type: "object"
        properties:
          name:
            type: "string"
          permissions:
            type: "object"
            properties:
              pages:
                description: "
                Allow to list all pages with its devices (read) or edit existing pages (write)
                "
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]               
              rules:
                description: """
                Allow to list all rules (read) or edit existing rules (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              variables:
                description: """
                Allow to list all variables (read) or edit existing variables (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              messages:
                description: """
                Allow to list all messages (read) or delete existing messages (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              events:
                description: """
                Allow to list all events (read) or delete existing events (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              devices:
                description: """
                Allow to list all devices (read) or edit existing devices (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              groups:
                description: """
                Allow to list all groups (read) or edit existing groups (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              users:
                description: """
                Allow to list all users (read) or edit existing users (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              plugins:
                description: """
                Allow to list all plugins (read) or edit existing plugins (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              updates:
                description: """
                Allow to search for updates or additional do updating
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              config:
                description: """
                Allow to show the config (read) or edit existing config (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              database:
                description: """
                Allow read and or write to the database
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              controlDevices:
                description: """
                Allow to control devices (switches, buttons, ...)
                """
                type: "boolean"
                default: false
              restart:
                description: """
                Allow to restart pimatic
                """
                type: "boolean"
                default: false
  patternProperties:
    '//.*': {
      description: "Comments"
      type: "string"
    }
}
