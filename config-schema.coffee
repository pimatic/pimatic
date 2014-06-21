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
            username:
              description: "The Username for http-basic-authentication"
              type: "string"
              default: ""
            password:
              description: "The Password for http-basic-authentication"
              type: "string"
              default: ""
            enabled:
              description: "Disable http-basic-authentication"
              type: "boolean"
              default: true
            loginTime:
              description: """The time in milliseconds to keep the session cookie if rememberMe is checked. 
              If 0 then delete the cookie on browser close.
              """
              type: "integer"
              default: 30 * 24 * 60 * 60 * 1000 #thirty days
        logLevel:
          description: "The log level: debug, info, warn, error" 
          type: "string"
          default: "info"
        httpServer:
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
          Download and run https://raw.githubusercontent.com/pimatic/pimatic/master/install/ssl-setup
          and un ssl-setup in you pimatic-app dir to generate the necessary key and certificate files:
          
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
            description: """The public root certificate file of your own CA if you using a self signed 
            certificate. This option is optional. Its just for the frontent, so that it can provide a 
            link to the the root certificate for easy importing in mobile devices."""
            type: "string"
            default: "ca/certs/cacert.crt"
        database:
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
            default: []
          messageLogging:
            description: "time to keep logged messages in database"
            type: "array"
            default: []
    pages:
      description: "Array of gui pages"
      type: "array"
      default: []
    groups:
      description: "Array of groups"
      type: "array"
      default: []
    plugins:
      description: "Array of plugins to load"
      type: "array"
      default: []
    devices:
      description: "Array of device definations"
      type: "array"
      default: []
    rules:
      description: "Array of rules"
      type: "array"
      default: []
    variables:
      description: "Array of variables"
      type: "array"
      default: []
}