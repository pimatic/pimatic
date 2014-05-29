###
API-Defs
=========
###

###
#Rules
###

api = {}

ruleParams =  {
  ruleId:
    type: String
  rule:
    type: Object
    properties:
      id:
        type: String
      name:
        type: String
      ruleString:
        type: String
      active:
        type: Boolean
      force: 
        type: Boolean
      logging:
        type: Boolean
}

api.rules = {
  actions:
    addRuleByString:
      description: "Adds a rule by a string"
      rest:
        type: "POST"
        url: "/api/rules/:ruleId"
      params: 
        ruleId: ruleParams.ruleId
        rule: ruleParams.rule
        force: 
          type: Boolean
    updateRuleByString:
      rest:
        type: "PATCH"
        url: "/api/rules/:ruleId"
      description: "Updates a rule by a string"
      params: ruleParams
    removeRule:
      rest:
        type: "DELETE"
        url: "/api/rules/:ruleId"
      description: "Remove the rule with the given id"
      params:
        ruleId:
          type: String
    getAllRules:
      rest:
        type: "GET"
        url: "/api/rules"
      description: "Lists all rules"
      params: {}
    getRuleById:
      rest:
        type: "GET"
        url: "/api/rules/:ruleId"
      description: "Lists all rules"
      params: 
        ruleId:
          type: String
}

###
#Variables
###

variableParams = {
  name:
    type: String
  type:
    type: ["expression", "value"]
  valueOrExpression:
    type: "any"
}

api.variables = {
  actions:
    getAllVariables:
      description: "Lists all variables"
      rest:
        type: "GET"
        url: "/api/variables"
      params: {}
      result:
        variables:
          type: Array
    updateVariable:
      description: "Updates a variable value or expression"
      rest:
        type: "PATCH"
        url: "/api/variables/:name"
      params: variableParams
    addVariable:
      description: "Adds a value or expression variable"
      rest:
        type: "POST"
        url: "/api/variables/:name"
      params: variableParams
    getVariableByName:
      description: "Get infos about a variable"
      rest:
        type: "GET"
        url: "/api/variables/:name"
      params:
        name:
          type: String
      result:
        variable:
          type: Object
    removeVariable:
      desciption: "Remove a variable"
      rest:
        type: "DELETE"
        url: "/api/variables/:name"
      params:
        name:
          type: String
}

###
#Framework
###
api.framework = {
  actions:
    getAllDevices:
      rest:
        type: "GET"
        url: "/api/devices"
      description: "Lists all devices"
      params: {}
      result:
        devices:
          type: Array
          toJson: yes 
    getDeviceById:
      description: "Lists all devices"
      rest:
        type: "GET"
        url: "/api/devices/:deviceId"
      params:
        deviceId:
          type: String
      result:
        device:
          type: Object
          toJson: yes
    addPluginsToConfig:
      description: "Add plugins to config"
      rest:
        type: "POST"
        url: "/api/config/plugins"
      params:
        pluginNames:
          type: Array
      result:
        added:
          type: Array
    removePluginsFromConfig:
      description: "Remove plugins from config"
      rest:
        type: "DELETE"
        url: "/api/config/plugins"
      params:
        pluginNames:
          type: Array
      result:
        removed:
          type: Array
    restart:
      description: "Restart pimatic"
      rest:
        type: "POST"
        url: "/api/restart"
      result: {}
}


###
#Plugins
###
api.plugins = {
  actions:
    getInstalledPluginsWithInfo:
      description: "Lists all installed plugins"
      rest:
        type: "GET"
        url: "/api/plugins"
      params: {}
    searchForPluginsWithInfo:
      description: "Searches for available plugins"
      rest:
        type: "GET"
        url: "/api/available-plugins"
      params: {}
    getOutdatedPlugins:
      description: "Get outdated plugins"
      rest:
        type: "GET"
        url: "/api/outdated-plugins"
      params: {}
      result:
        outdatedPlugins:
          type: Array
    isPimaticOutdated:
      description: "Is pimatic outdated"
      rest:
        type: "GET"
        url: "/api/outdated-pimatic"
      params: {}
      result:
        outdated: 
          tye: 'any'
    installUpdatesAsync:
      description: "Install Updates without awaiting result"
      rest:
        type: "POST"
        url: "/api/update-async"
      params:
        modules:
          type: Array
      result:
        status:
          type: 'any'
}


###
#Database
###
messageCriteria = {
  criteria:
    type: Object
    optional: yes
    properties:
      level:
        type: 'any'
        optional: yes
      levelOp:
        type: String
        optional: yes
      after:
        type: Date
        optional: yes
      before:
        type: Date
        optional: yes
      limit:
        type: Number
        optional: yes
}
  
dataCriteria = {
  criteria:
    type: Object
    optional: yes
    properties:
      deviceId:
        type: "any"
      attributeName:
        type: "any"
      after:
        type: Date
      before:
        type: Date
}

api.database = {
  actions:
    queryMessages:
      desciption: "list log messages"
      rest:
        type: 'GET'
        url: '/api/database/messages'
      params: messageCriteria
      result:
        messages:
          type: Array
    deleteMessages:
      description: "delets messages older than the given date"
      rest:
        type: 'DELETE'
        url: '/api/database/messages'
      params: messageCriteria
    addDeviceAttributeLogging:
      description: "enable or disable logging for an device attribute"
      params:
        deviceId:
          type: String
        attributeName:
          type: String
        time:
          type: "any"
    queryMessagesTags:
      description: "lists all tags from the matching messages"
      rest:
        type: 'GET'
        url: '/api/database/messages/tags'
      params: messageCriteria
      result:
        tags:
          type: Array
    queryMessagesCount:
      description: "count of all matches matching the criteria"
      rest:
        type: 'GET'
        url: '/api/database/messages/count'
      params: messageCriteria
      result:
        count:
          type: Number
    queryDeviceAttributeEvents:
      rest:
        type: 'GET'
        url: '/api/database/device-attributes/'
      description: "get logged values of device attributes"
      params: dataCriteria
      result:
        events:
          type: Array
    getDeviceAttributeLogging:
      description: "get device attribute logging times table"
      params: {}
      result:
        attributeLogging:
          type: Array
    setDeviceAttributeLogging:
      description: "set device attribute logging times table"
      params:
        attributeLogging:
          type: Array
    getDeviceAttributeLoggingTime:
      description: "get device attribute logging times table"
      params:
        deviceId:
          type: String
        attributeName:
          type: String
      result:
        timeInfo:
          type: Object
}

module.exports = api