###
API-Defs
=========
###

t = require('decl-api').types

###
#Rules
###

api = {}

###
#Framework
###

device = {
  type: t.object
  properties:
    id:
      description: "A user chosen string, used to identify that device."
      type: t.string
    name:
      description: "A user chosen string that should be used to display the device."
      type: t.string
    template:
      description: "Name of the template, that should be used to display the device."
      type: t.string
    attributes:
      description: "List of all attributes of the device."
      type: t.array
    actions:
      description: "List of all Actions of the device."
      type: t.array
    config: 
      description: "Config of the device, without default values."
      type: t.object
    configDefaults:
      description: "Default values for the config options."
      type: t.object
}

page = {
  type: t.object
  properties:
    id: 
      description: "A user chosen string, used to identify the page."
      type: t.string
    name: 
      description: "A user chosen string that should be used to display the page."
      type: t.string
    devices:
      description: "List of all device ids that should be displayed on that page"
      type: t.array
      items:
        deviceItem:
          type: t.object
          properties:
            deviceId:
              description: "The id of the device to display at that position"
              type: t.string
}

api.framework = {
  events:
    deviceAdded:
      description: "A new device was added to the devices list"
      params:
        device:
          type: t.object
          toJson: yes
    deviceAttributeChanged:
      description: "The value of a device attribute changed"
      params:
        event:
          type: t.object
          properties:
            device:
              type: t.object
              toJson: yes
            attributeName:
              type: t.string
            attribute:
              type: t.object
            time:
              type: t.date
            value: 
              type: t.any
    messageLogged:
      description: "A new log message was emitted"
      params:
        event:
          type: t.object
          properties:
            level:
              type: t.string
            msg:
              type: t.string
            meta:
              type: t.object
  actions:
    getDevices:
      description: "Lists all devices."
      rest:
        type: "GET"
        url: "/api/devices"
      params: {}
      result:
        devices:
          description: "Array of all devices."
          type: t.array
          toJson: yes
          items: 
            device: device
    getDeviceById:
      description: "Retrieve a device by a given id."
      rest:
        type: "GET"
        url: "/api/devices/:deviceId"
      params:
        deviceId:
          description: "The id of the device that should be returned."
          type: t.string
      result:
        device:
          description: "The requested device or null if the device was not found."
          type: t.object
          toJson: yes
          properties: device.properties
    getPages:
      description: "Lists all pages."
      rest:
        type: "GET"
        url: "/api/pages"
      params: {}
      result:
        pages:
          type: t.array
          items:
            page: page
    getPageById:
      description: "Get a page by id"
      rest:
        type: "GET"
        url: "/api/pages/:pageId"
      params:
        pageId:
          description: "The id of the page that should be returned."
          type: t.string
      result:
        page:
          description: "The requested page or null if the page was not found."
          type: t.object
          properties: page.properties
    removePage:
      description: "Remove a page."
      rest:
        type: "DELETE"
        url: "/api/pages/:pageId"
      params:
        pageId:
          description: "The id of the page that should be removed."
          type: t.string
      result:
        removed:
          description: "The removed page."
          type: t.object
          properties: page.properties
    addPage:
      rest:
        type: "POST"
        url: "/api/pages/:pageId"
      description: "Add a page."
      params:
        pageId:
          description: "The id of the page that should be added."
          type: t.string
        page:
          description: "Object with id and name of the page to create."
          type: t.object
          properties:
            name: 
              description: "A user chosen string that should be used to display the page."
              type: t.string
      result:
        page:
          description: "The created page."
          type: t.object
          properties: page.properties
    updatePage:
      description: "Update a page name or device order."
      rest:
        type: "PATCH"
        url: "/api/pages/:pageId"
      params:
        pageId:
          description: "The id of the page to change."
          type: t.string
        page:
          description: "An object with properties that should be updated."
          type: t.object
          properties:
            name:
              description: "The new name to set."
              type: t.string
              optional: yes
            devicesOrder:
              description: "Array of ordered deviceIds."
              type: t.array
              optional: yes
              items:
                deviceId:
                  type: t.string
      result:
        page:
          description: "The updated page."
          type: t.object
          properties: page.properties
    addDeviceToPage:
      rest:
        type: "POST"
        url: "/api/pages/:pageId/devices/:deviceId"
      description: "Add a page"
      params:
        pageId:
          type: t.string
        deviceId:
          type: t.string
      result:
        page:
          type: t.object
    removeDeviceFromPage:
      rest:
        type: "DELETE"
        url: "/api/pages/:pageId/devices/:deviceId"
      description: "Add a page"
      params:
        pageId:
          type: t.string
        deviceId:
          type: t.string
      result:
        page:
          type: t.object   
    removeGroup:
      description: "Remove group"
      rest:
        type: "DELETE"
        url: "/api/groups/:groupId"
      params:
        groupId:
          type: t.string
      result:
        removed:
          type: t.object
    addGroup:
      rest:
        type: "POST"
        url: "/api/groups/:groupId"
      description: "Add a group"
      params:
        groupId:
          type: t.string
        group:
          type: t.object
      result:
        group:
          type: t.object
    updateGroup:
      rest:
        type: "PATCH"
        url: "/api/groups/:groupId"
      description: "Update a group"
      params:
        groupId:
          type: t.string
        group:
          type: t.object
          properties:
            name:
              type: t.name
              optional: yes
            devicesOrder:
              type: t.array
              optional: yes
            variablesOrder:
              type: t.array
              optional: yes
            rulesOrder:
              type: t.array
              optional: yes
      result:
        group:
          type: t.object
    addDeviceToGroup:
      rest:
        type: "POST"
        url: "/api/groups/:groupId/devices/:deviceId"
      description: "Add a device to a group"
      params:
        groupId:
          type: t.string
        deviceId:
          type: t.string
      result:
        deviceItem:
          type: t.object
    removeDeviceFromGroup:
      rest:
        type: "DELETE"
        url: "/api/groups/:groupId/devices/:deviceId"
      description: "Removes a device from a group"
      params:
        groupId:
          type: t.string
        deviceId:
          type: t.string
      result:
        group:
          type: t.object  
    addRuleToGroup:
      rest:
        type: "POST"
        url: "/api/groups/:groupId/rules/:ruleId"
      description: "Add a rule to a group"
      params:
        groupId:
          type: t.string
        ruleId:
          type: t.string
        position:
          type: t.number
          optional: yes
      result:
        group:
          type: t.object
    removeRuleFromGroup:
      rest:
        type: "DELETE"
        url: "/api/groups/:groupId/rules/:ruleId"
      description: "Removes a rule from a group"
      params:
        groupId:
          type: t.string
        ruleId:
          type: t.string
      result:
        group:
          type: t.object  
    updateRuleGroupOrder:
      rest:
        type: "POST"
        url: "/api/groups/:groupId/rules"
      description: "Add a rule to a group"
      params:
        groupId:
          type: t.string
        ruleOrder:
          type: t.array
      result:
        group:
          type: t.object
    addVariableToGroup:
      rest:
        type: "POST"
        url: "/api/groups/:groupId/variables/:variableName"
      description: "Add a variable to a group"
      params:
        groupId:
          type: t.string
        variableName:
          type: t.string
        position:
          type: t.number
          optional: yes
      result:
        group:
          type: t.object
    updateDeviceGroupOrder:
      rest:
        type: "POST"
        url: "/api/groups/:groupId/devices"
      description: "Update device order in group"
      params:
        groupId:
          type: t.string
        deviceOrder:
          type: t.array
      result:
        group:
          type: t.object
    removeVariableFromGroup:
      rest:
        type: "DELETE"
        url: "/api/groups/:groupId/variables/:variableName"
      description: "Removes a variable from a group"
      params:
        groupId:
          type: t.string
        variableName:
          type: t.string
      result:
        group:
          type: t.object  
    updateVariableGroupOrder:
      rest:
        type: "POST"
        url: "/api/groups/:groupId/variables"
      description: "Update variable order in group"
      params:
        groupId:
          type: t.string
        variableOrder:
          type: t.array
      result:
        group:
          type: t.object   
    updateRuleOrder:
      rest:
        type: "POST"
        url: "/api/rules"
      description: "Update the Order of all rules"
      params:
        ruleOrder:
          type: t.array
      result:
        ruleOrder:
          type: t.array
    updateDeviceOrder:
      rest:
        type: "POST"
        url: "/api/devices"
      description: "Update the Order of all devices"
      params:
        deviceOrder:
          type: t.array
      result:
        deviceOrder:
          type: t.array
    updateVariableOrder:
      rest:
        type: "POST"
        url: "/api/variables"
      description: "Update the Order of all variables"
      params:
        variableOrder:
          type: t.array
      result:
        variableOrder:
          type: t.array
    updateGroupOrder:
      rest:
        type: "POST"
        url: "/api/groups"
      description: "Update the Order of all Groups"
      params:
        groupOrder:
          type: t.array
      result:
        groupOrder:
          type: t.array
    addPluginsToConfig:
      description: "Add plugins to config"
      rest:
        type: "POST"
        url: "/api/config/plugins"
      params:
        pluginNames:
          type: t.array
      result:
        added:
          type: t.array
    removePluginsFromConfig:
      description: "Remove plugins from config"
      rest:
        type: "DELETE"
        url: "/api/config/plugins"
      params:
        pluginNames:
          type: t.array
      result:
        removed:
          type: t.array
    restart:
      description: "Restart pimatic"
      rest:
        type: "POST"
        url: "/api/restart"
      result:
        void: {}
    getDeviceClasses:
      description: "List all registered device classes."
      rest:
        type: "GET"
        url: "/api/device-class"
      result:
        deviceClasses:
          type: t.array
    getDeviceConfigSchema:
      description: "Gets the config schema of a device class."
      rest:
        type: "GET"
        url: "/api/device-class/:className"
      params:
        className:
          type: t.string
      result:
        configSchema:
          type: t.object
    addDeviceByConfig:
      description: "Add a device by config values"
      rest:
        type: "POST"
        url: "/api/device-config"
      params:
        deviceConfig:
          type: t.object
      result:
        device: device
    updateDeviceByConfig:
      description: "Update a device by config values"
      rest:
        type: "PATCH"
        url: "/api/device-config"
      params:
        deviceConfig:
          type: t.object
      result:
        device: device
    removeDevice:
      description: "Removes a device from the framework an config"
      rest:
        type: "DELETE"
        url: "/api/device-config/:deviceId"
      params:
        deviceId:
          type: t.string
      result:
        device: device
}

api.rules = {
  actions:
    addRuleByString:
      description: "Adds a rule by a string"
      rest:
        type: "POST"
        url: "/api/rules/:ruleId"
      params: 
        ruleId:
          type: t.string
        rule:
          type: t.object
          properties:
            name:
              type: t.string
            ruleString:
              type: t.string
            active:
              type: t.boolean
              optional: yes
            logging:
              type: t.boolean
              optional: yes
        force: 
          type: t.boolean
          optional: yes
    updateRuleByString:
      rest:
        type: "PATCH"
        url: "/api/rules/:ruleId"
      description: "Updates a rule by a string"
      params:
        ruleId:
          type: t.string
        rule:
          type: t.object
          properties:
            name:
              type: t.string
              optional: yes
            ruleString:
              type: t.string
              optional: yes
            active:
              type: t.boolean
              optional: yes
            logging:
              type: t.boolean
              optional: yes
    removeRule:
      rest:
        type: "DELETE"
        url: "/api/rules/:ruleId"
      description: "Remove the rule with the given id"
      params:
        ruleId:
          type: t.string
    getRules:
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
          type: t.string
}

###
#Variables
###

variableParams = {
  name:
    type: t.string
  type:
    type: t.string
    enum: ["expression", "value"]
  valueOrExpression:
    type: t.string
}

variableResult = {
  variable:
    type: t.object
    toJson: yes
}

api.variables = {
  actions:
    getVariables:
      description: "Lists all variables"
      rest:
        type: "GET"
        url: "/api/variables"
      params: {}
      result:
        variables:
          type: t.array
          toJson: yes
    updateVariable:
      description: "Updates a variable value or expression"
      rest:
        type: "PATCH"
        url: "/api/variables/:name"
      params: variableParams
      result: variableResult
    addVariable:
      description: "Adds a value or expression variable"
      rest:
        type: "POST"
        url: "/api/variables/:name"
      params: variableParams
      result: variableResult
    getVariableByName:
      description: "Get infos about a variable"
      rest:
        type: "GET"
        url: "/api/variables/:name"
      params:
        name:
          type: t.string
      result: variableResult
    removeVariable:
      description: "Remove a variable"
      rest:
        type: "DELETE"
        url: "/api/variables/:name"
      params:
        name:
          type: t.string
      result: variableResult

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
      result:
        plugins:
          type: t.array
    searchForPluginsWithInfo:
      description: "Searches for available plugins"
      rest:
        type: "GET"
        url: "/api/available-plugins"
      params: {}
      result:
        plugins:
          type: t.array
    getOutdatedPlugins:
      description: "Get outdated plugins"
      rest:
        type: "GET"
        url: "/api/outdated-plugins"
      params: {}
      result:
        outdatedPlugins:
          type: t.array
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
          type: t.array
      result:
        status:
          type: 'any'
}


###
#Database
###
messageCriteria = {
  criteria:
    type: t.object
    optional: yes
    properties:
      level:
        type: 'any'
        optional: yes
      levelOp:
        type: t.string
        optional: yes
      after:
        type: t.date
        optional: yes
      before:
        type: t.date
        optional: yes
      limit:
        type: t.number
        optional: yes
}
  
dataCriteria = {
  criteria:
    type: t.object
    optional: yes
    properties:
      deviceId:
        type: [t.string, t.array]
        optional: yes
      attributeName:
        type: [t.string, t.array]
        optional: yes
      after:
        type: t.date
        optional: yes
      before:
        type: t.date
        optional: yes
      order:
        type: t.string
        optional: yes
      orderDirection:
        type: t.string
        optional: yes
      offset:
        type: t.number
        optional: yes
      limit:
        type: t.number
        optional: yes
}

api.database = {
  actions:
    queryMessages:
      description: "list log messages"
      rest:
        type: 'GET'
        url: '/api/database/messages'
      params: messageCriteria
      result:
        messages:
          type: t.array
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
          type: t.string
        attributeName:
          type: t.string
        time:
          type: t.any
    queryMessagesTags:
      description: "lists all tags from the matching messages"
      rest:
        type: 'GET'
        url: '/api/database/messages/tags'
      params: messageCriteria
      result:
        tags:
          type: t.array
    queryMessagesCount:
      description: "count of all matches matching the criteria"
      rest:
        type: 'GET'
        url: '/api/database/messages/count'
      params: messageCriteria
      result:
        count:
          type: t.number
    queryDeviceAttributeEvents:
      rest:
        type: 'GET'
        url: '/api/database/device-attributes/'
      description: "get logged values of device attributes"
      params: dataCriteria
      result:
        events:
          type: t.array
    querySingleDeviceAttributeEvents:
      rest:
        type: 'GET'
        url: '/api/database/device-attributes/:deviceId/:attributeName'
      description: "get logged values of device attributes"
      params:
        deviceId:
          type: t.string
        attributeName:
          type: t.string
        criteria:
          type: t.object
          optional: yes
          properties:
            after:
              type: t.date
              optional: yes
            before:
              type: t.date
              optional: yes
            order:
              type: t.string
              optional: yes
            orderDirection:
              type: t.string
              optional: yes
            offset:
              type: t.number
              optional: yes
            limit:
              type: t.number
              optional: yes
      result:
        events:
          type: t.array
    getDeviceAttributeLogging:
      description: "get device attribute logging times table"
      params: {}
      result:
        attributeLogging:
          type: t.array
    setDeviceAttributeLogging:
      description: "set device attribute logging times table"
      params:
        attributeLogging:
          type: t.array
    getDeviceAttributeLoggingTime:
      description: "get device attribute logging times table"
      params:
        deviceId:
          type: t.string
        attributeName:
          type: t.string
      result:
        timeInfo:
          type: t.object
}

# all
actions = {}
for a in [api.framework, api.rules, api.variables, api.plugins, api.database]
  for actionName, action of a.actions
    actions[actionName] = action
api.all = {actions}

module.exports = api