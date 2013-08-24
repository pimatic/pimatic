# #Configuration options 
# Lists all configuration options for the sweetpi framework itself.
# For an example `config.json` file see the `config_default.json` file.

# Defines a `node-convict` config-shema and exports it.
module.exports =
  auth:
    username:
      doc: "The Username for http-basic-authentification"
      format: String
      default: ""
    password:
      doc: "The Password for http-basic-authentification"
      format: String
      default: ""
    disableAuthentication:
      doc: "Disable http-basic-authentification"
      format: Boolean
      default: false
  server:
    httpServer:
      enabled: 
        doc: "Should the http-server be started"
        format: Boolean
        default: true
      port:
        doc: "The port of the http-server"
        format: "port"
        default: 80
    httpsServer:
      enabled: 
        doc: "Should the https-server be started"
        format: Boolean
        default: false
      port:
        doc: "The port of the https-server"
        format: "port"
        default: 443
      keyFile:
        doc: "Certification-file in pem-format"
        format: String
        default: "./.cert/privatekey.pem"
      certFile:
        doc: "Privatekey-file"
        format: String
        default: "./.cert/certificate.pem"
  frontends:
    doc: "Array of frontends to load"
    format: Array
    default: []
  backends:
    doc: "Array of backends to load"
    format: Array
    default: []
  actuartos:
    doc: "Array of actuator definations"
    format: Array
    default: []