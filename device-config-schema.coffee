module.exports =
  ButtonsDevice:
    buttons:
      description: "Buttons to display"
      type: "array"
      default: []
      format: "table"
      items:
        type: "object"
        properties:
          id:
            type: "string"
          text:
            type: "string"