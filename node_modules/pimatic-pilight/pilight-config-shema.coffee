# #pilight configuration options

# Defines a `node-convict` config-shema and exports it.
module.exports =
  host:
    doc: "The ip or host to connect to the piligt-daemon"
    format: String
    default: "127.0.0.1"
  port:
    doc: "port to connect to the piligt-daemon"
    format: "port"
    default: 5000
  timeout:
    doc: "timeout for requests"
    format: Number
    default: 3000