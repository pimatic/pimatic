winston = require 'winston'

logger = new (winston.Logger)(
  transports: [
    new (winston.transports.Console)(
      level: 'debug'
      colorize: true
    )
  ]
)

module.exports = logger