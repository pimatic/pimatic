###
API-Defs
=========
###

assert = require 'assert'
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
  toJson: yes
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
    getGuiSetttings:
      description: "Get the gui config options"
      rest: 
        type: "GET"
        url: "/api/config/settings/gui"
      result:
        guiSettings:
          type: "object"
          properties:
            config:
              type: "object"
            defaults:
              type: "object"
    restart:
      description: "Restart pimatic"
      rest:
        type: "POST"
        url: "/api/restart"
      result:
        void: {}
      permission:
        action: "restart"
    getConfig:
      description: "Get the config, if no password is provided password fields will be blanked"
      rest:
        type: "GET"
        url: '/api/config'
      params:
        password:
          type: t.string
          optional: yes
      result:
        config:
          description: "the config"
          type: t.object
      permission:
        scope: "config"
        access: "read"
    updateConfig:
      description: "Update the config"
      rest:
        type: "POST"
        url: '/api/config'
      params:
        config:
          type: t.object
      permission:
        scope: "config"
        access: "write"        
}

api.devices = {
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
      permission:
        scope: "devices"
        access: "read"
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
      permission:
        scope: "devices"
        access: "read"
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
      permission:
        scope: "devices"
        access: "write"
    getDeviceClasses:
      description: "List all registered device classes."
      rest:
        type: "GET"
        url: "/api/device-class"
      result:
        deviceClasses:
          type: t.array
      permission:
        scope: "devices"
        access: "read"
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
      permission:
        scope: "devices"
        access: "read"
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
      permission:
        scope: "devices"
        access: "write"
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
      permission:
        scope: "devices"
        access: "write"
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
      permission:
        scope: "devices"
        access: "write"
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
      permission:
        scope: "rules"
        access: "write"
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
      permission:
        scope: "rules"
        access: "write"
    removeRule:
      rest:
        type: "DELETE"
        url: "/api/rules/:ruleId"
      description: "Remove the rule with the given id"
      params:
        ruleId:
          type: t.string
      permission:
        scope: "rules"
        access: "write"
    getRules:
      rest:
        type: "GET"
        url: "/api/rules"
      description: "Lists all rules"
      params: {}
      result:
        rules:
          type: t.array
          toJson: yes
      permission:
        scope: "rules"
        access: "write"
    getRuleById:
      rest:
        type: "GET"
        url: "/api/rules/:ruleId"
      description: "Lists all rules"
      params:
        ruleId:
          type: t.string
      result:
        rule:
          type: "object"
          toJson: yes
      permission:
        scope: "rules"
        access: "read"
    getRuleActionsHints:
      rest:
        type: "POST"
        url: "/api/rules-parser/get-actions-hints"
      description: "Get hints for the rule actions input field"
      params:
        actionsInput:
          type: t.string
      result:
        hints:
          type: t.object
          properties:
            actions:
              type: t.array
            tokens:
              type: t.array
            autocomplete:
              type: t.array
            errors:
              type: t.array
            warnings:
              type: t.array
            format:
              type: t.array
      permission:
        scope: "rules"
        access: "read"
    getRuleConditionHints:
      rest:
        type: "POST"
        url: "/api/rules-parser/get-condition-hints"
      description: "Get hints for the rule condition input field"
      params:
        conditionInput:
          type: t.string
      result:
        hints:
          type: t.object
          properties:
            predicates:
              type: t.array
            tokens:
              type: t.array
            autocomplete:
              type: t.array
            errors:
              type: t.array
            warnings:
              type: t.array
            format:
              type: t.array
      permission:
        scope: "rules"
        access: "read"
    executeAction:
      rest:
        type: "POST"
        url: "/api/execute-action"
      description: "Execute a rule action by a given string"
      params:
        actionString:
          description: "The action to executed"
          type: t.string
        simulate:
          description: "If it is true then only simulate the action."
          type: t.boolean
          optional: yes
        logging:
          description: "Log result message"
          type: t.string
          optional: yes
      result:
        message:
          type: t.string
      permission:
        scope: "rules"
        access: "write"
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
      permission:
        scope: "rules"
        access: "write"
}


api.pages = {
  actions:
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
      permission:
        scope: "pages"
        access: "read"
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
      permission:
        scope: "pages"
        access: "read"
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
      permission:
        scope: "pages"
        access: "write"
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
      permission:
        scope: "pages"
        access: "write"
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
      permission:
        scope: "pages"
        access: "write"
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
      permission:
        scope: "pages"
        access: "write"
    removeDeviceFromPage:
      rest:
        type: "DELETE"
        url: "/api/pages/:pageId/devices/:deviceId"
      description: "Remove a Device from a group."
      params:
        pageId:
          type: t.string
        deviceId:
          type: t.string
      result:
        page:
          type: t.object
      permission:
        scope: "pages"
        access: "write"
    updatePageOrder:
      rest:
        type: "POST"
        url: "/api/pages"
      description: "Update the Order of all Pages"
      params:
        pageOrder:
          type: t.array
      result:
        pageOrder:
          type: t.array
      permission:
        scope: "pages"
        access: "write"
}

api.groups = {
  actions:
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
      permission:
        scope: "groups"
        access: "write"
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
      permission:
        scope: "groups"
        access: "write"
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
      permission:
        scope: "groups"
        access: "write"
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
      permission:
        scope: "groups"
        access: "write"
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
      permission:
        scope: "groups"
        access: "write"
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
      permission:
        scope: "rules"
        access: "write"
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
      permission:
        scope: "rules"
        access: "write"
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
      permission:
        scope: "rules"
        access: "write"
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
      permission:
        scope: "variables"
        access: "write"
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
      permission:
        scope: "devices"
        access: "write"
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
      permission:
        scope: "variables"
        access: "write"
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
      permission:
        scope: "variables"
        access: "write"
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
      permission:
        scope: "groups"
        access: "write"
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
  unit:
    type: t.string
    optional: yes
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
      permission:
        scope: "variables"
        access: "read"
    updateVariable:
      description: "Updates a variable value or expression"
      rest:
        type: "PATCH"
        url: "/api/variables/:name"
      params: variableParams
      result: variableResult
      permission:
        scope: "variables"
        access: "write"
    addVariable:
      description: "Adds a value or expression variable"
      rest:
        type: "POST"
        url: "/api/variables/:name"
      params: variableParams
      result: variableResult
      permission:
        scope: "variables"
        access: "write"
    getVariableByName:
      description: "Get infos about a variable"
      rest:
        type: "GET"
        url: "/api/variables/:name"
      params:
        name:
          type: t.string
      result: variableResult
      permission:
        scope: "variables"
        access: "read"
    removeVariable:
      description: "Remove a variable"
      rest:
        type: "DELETE"
        url: "/api/variables/:name"
      params:
        name:
          type: t.string
      permission:
        scope: "variables"
        access: "write"
      result: variableResult
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
      permission:
        scope: "variables"
        access: "write"
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
      permission:
        scope: "plugins"
        access: "read"
    searchForPluginsWithInfo:
      description: "Searches for available plugins"
      rest:
        type: "GET"
        url: "/api/available-plugins"
      params: {}
      result:
        plugins:
          type: t.array
      permission:
        scope: "plugins"
        access: "read"
    getOutdatedPlugins:
      description: "Get outdated plugins"
      rest:
        type: "GET"
        url: "/api/outdated-plugins"
      params: {}
      result:
        outdatedPlugins:
          type: t.array
      permission:
        scope: "updates"
        access: "read"
    isPimaticOutdated:
      description: "Is pimatic outdated"
      rest:
        type: "GET"
        url: "/api/outdated-pimatic"
      params: {}
      result:
        outdated:
          tye: 'any'
      permission:
        scope: "updates"
        access: "read"
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
      permission:
        scope: "updates"
        access: "write"
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
      permission:
        scope: "plugins"
        access: "write"
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
      permission:
        scope: "plugins"
        access: "write"
    getUpdateProcessStatus:
      description: "Get update status"
      rest:
        type: "GET"
        url: "/api/update-process"
      result:
        info:
          type: "object"
      permission:
        scope: "updates"
        access: "none"
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
      permission:
        scope: "messages"
        access: "read"
    deleteMessages:
      description: "delets messages older than the given date"
      rest:
        type: 'DELETE'
        url: '/api/database/messages'
      params: messageCriteria
      permission:
        scope: "messages"
        access: "write"
    addDeviceAttributeLogging:
      description: "enable or disable logging for an device attribute"
      params:
        deviceId:
          type: t.string
        attributeName:
          type: t.string
        time:
          type: t.any
      permission:
        scope: "events"
        access: "read"
    queryMessagesTags:
      description: "lists all tags from the matching messages"
      rest:
        type: 'GET'
        url: '/api/database/messages/tags'
      params: messageCriteria
      result:
        tags:
          type: t.array
      permission:
        scope: "messages"
        access: "read"
    queryMessagesCount:
      description: "count of all matches matching the criteria"
      rest:
        type: 'GET'
        url: '/api/database/messages/count'
      params: messageCriteria
      result:
        count:
          type: t.number
      permission:
        scope: "messages"
        access: "read"
    queryDeviceAttributeEvents:
      rest:
        type: 'GET'
        url: '/api/database/device-attributes/'
      description: "get logged values of device attributes"
      params: dataCriteria
      result:
        events:
          type: t.array
      permission:
        scope: "events"
        access: "read"
    queryDeviceAttributeEventsCount:
      rest:
        type: 'GET'
        url: '/api/database/device-attributes/count'
      description: "Get count of saved device attributes events"
      params: {}
      result:
        count:
          type: t.number
      permission:
        scope: "events"
        access: "read"
    queryDeviceAttributeEventsDevices:
      rest:
        type: 'GET'
        url: '/api/database/device-attributes/devices'
      description: "get logged values of all device attributes"
      params: {}
      result:
        devices:
          type: t.array
      permission:
        scope: "events"
        access: "read"
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
            groupByTime:
              type: t.number
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
      permission:
        scope: "events"
        access: "read"
    getDeviceAttributeLogging:
      description: "get device attribute logging times table"
      params: {}
      result:
        attributeLogging:
          type: t.array
      permission:
        scope: "events"
        access: "read"
    setDeviceAttributeLogging:
      description: "set device attribute logging times table"
      params:
        attributeLogging:
          type: t.array
      permission:
        scope: "events"
        access: "write"
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
      permission:
        scope: "events"
        access: "read"
}

# all
actions = {}
apis = [
  api.framework,
  api.rules,
  api.variables,
  api.plugins,
  api.database,
  api.groups,
  api.pages
  api.devices
]
for a in apis
  for actionName, action of a.actions
    assert(not actions[actionName]?)
    actions[actionName] = action
api.all = {actions}

module.exports = api