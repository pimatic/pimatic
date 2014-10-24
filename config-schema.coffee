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
          enum: ['en', 'de', "es", "nl"]
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
              description: """Secret string used for cookie signing. Should be kept secret. If it 
              is not set, then a secret will be generate for you, at first start. The secret must
              be at least 32 characters long.
              """
              secret: yes
            loginTime:
              description: """The time in milliseconds to keep the session cookie if rememberMe is 
              checked. If 0 then delete the cookie on browser close. """
              type: "integer"
              default: 10 * 365 * 24 * 60 * 60 * 1000 #ten years
        logLevel:
          description: "The log level: debug, info, warn, error" 
          type: "string"
          default: "info"
        httpServer:
          type: "object"
          properties:
            enabled: 
              description: "Should the http-server be started"
              type: "boolean"
              default: true
            port:
              description: "The port of the http-server"
              type: "integer"
              format: "port"
              default: 80
              minimum: 0
            hostname:
              description: "The hostname of the http-server"
              type: "string"
              default: "" # If is empty then listen to all ip4Adresses
        httpsServer:
          type: "object"
          properties:
            enabled: 
              description: "Should the https-server be started"
              type: "boolean"
              default: false
            port:
              description: "The port of the https-server"
              type: "integer"
              format: "port"
              default: 443
              minimum: 0
            hostname:
              description: "The hostname of the https-server"
              type: "string"
              default: "" # If is empty then listen to all ip4Adresses
            ###
            Download https://raw.githubusercontent.com/pimatic/pimatic/master/install/ssl-setup
            and run ssl-setup in you pimatic-app dir to generate the necessary key and certificate 
            files:
            
                wget https://raw.githubusercontent.com/pimatic/pimatic/master/install/ssl-setup
                chmod +x ssl-setup
                ./ssl-setup

            ###
            keyFile:
              description: "Privatekey file"
              type: "string"
              default: "ca/pimatic-ssl/private/privkey.pem"
            certFile:
              description: "Public certification file in pem-format"
              type: "string"
              default: "ca/pimatic-ssl/public/cert.pem"
            rootCertFile:
              description: """The public root certificate file of your own CA if you using a self 
              signed  certificate. This option is optional. Its just for the frontent, so that it 
              can provide a link to the the root certificate for easy importing in mobile devices.
              """
              type: "string"
              default: "ca/certs/cacert.crt"
        database:
          type: "object"
          properties:
            client: 
              description: "the databse client to use"
              type: "string"
              enum: ["sqlite3", "mysql", "pg"]
              default: "sqlite3"
            ###
            The connection setting is database client dependent. Some examples:
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
              description: "the connection settings for the database client"
              type: "object"
              default: {
                filename: "pimatic-database.sqlite"
              }
            deviceAttributeLogging:
              description: "time to keep logged device attributes values in database"
              type: "array"
              default: [ 
                { deviceId: '*', attributeName: '*', time: '7d' }
                { deviceId: '*', attributeName: 'temperature', time: '1y' },
                { deviceId: '*', attributeName: 'humidity', time: '1y' } 
              ]
            messageLogging:
              description: "time to keep logged messages in database"
              type: "array"
              default: [ 
                { level: '*', tags: [], time: '7d' }
              ]
            debug: 
              description: "Enable to show database queries and some additional outputs"
              type: "boolean"
              default: false
        gui:
          type: "object"
          properties:
            hideRuleName: 
              description: "Dont show the name of rules on the rules page"
              type: "boolean"
              default: false
            hideRuleText: 
              description: "Dont show the text of rules on the rules page"
              type: "boolean"
              default: false
            demo:
              doc: """show edit pages also if the user has no permissions, 
              like at demo.pimatic.org:8080
              """
              type: "boolean"
              default: false
    pages:
      description: "Array of gui pages"
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
    devices:
      description: "Array of device definations"
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
            description: "The loginname of the user"
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
                description: """Allow to list all pages with its devices (read) or additional 
                edit the pages (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]               
              rules:
                description: """
                Allow to list all rules (read) or additional edit the rules (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              variables:
                description: """
                Allow to list all variables (read) or additional edit the variables (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              messages:
                description: """
                Allow to list all messages (read) or additional edit the messages (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              events:
                description: """
                Allow to list all events (read) or additional edit the events (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              devices:
                description: """
                Allow to list all devices (read) or additional edit the devices (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              groups:
                description: """
                Allow to list all groups (read) or additional edit the groups (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              users:
                description: """
                Allow to list all users (read) or additional edit the users (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              plugins:
                description: """
                Allow to list all plugins (read) or additional edit the plugins (write)
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              updates:
                description: """
                Allow to show update or additional do updating
                """
                type: "string"
                default: "none"
                enum: ["none", "read", "write"]
              config:
                description: """
                Allow show the config (read) or additional edit the config (write)
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
}