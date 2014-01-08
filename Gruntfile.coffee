module.exports = (grunt) ->

  path = require "path"
  # all node_modules:
  modules = require("fs").readdirSync ".."
  # just the pimatic-* modules:
  plugins = (module for module in modules when module.match(/^pimatic-.*/)?)

  # files for generating documentation:
  grocFiles = [
    "./README.md"
    "./startup.coffee"
    "./config-shema.coffee"
    "./lib/*.coffee"
  ]

  # some realy dirty tricks:
  usedGroc = require('./node_modules/grunt-groc/node_modules/groc')
  ownGroc = require('./node_modules/groc')
  for name, prop of ownGroc
    usedGroc[name] = prop


  links =
    'pimatic framework': '/'

  for l in plugins
    short = l.replace 'pimatic-', ''
    links[short] = l

  grocTasks =
    pimatic:
      src: [
        "./README.md"
        "./plugins.md"
        "./startup.coffee"
        "./config-shema.coffee"
        "./lib/*.coffee"
      ]
      options: 
        root: "."
        out: "doc"
        "repository-url": "https://github.com/sweetpi/pimatic"
        style: 'pimatic'
        links: JSON.stringify links

  pluginLinks =
    'pimatic framework': '..'

  for l in plugins
    short = l.replace 'pimatic-', ''
    pluginLinks[short] = "../#{l}"
 
          
  for plugin in plugins
    grocTasks[plugin] =
      src: [
        "../#{plugin}/README.md"
        "../#{plugin}/*.coffee"
      ]
      options: 
        root: "../#{plugin}"
        out: "../#{plugin}/doc"
        "repository-url": "https://github.com/sweetpi/pimatic"
        links: JSON.stringify pluginLinks



  ftpTasks = {}
  for plugin in ["pimatic"].concat plugins 
    ftpTasks[plugin] =
      auth:
        host: "sweetpi.de"
        port: 21
      authKey: 'sweetpi.de'
      src: path.resolve __dirname, '..', plugin, "doc"
      dest: (if plugin is "pimatic" then "/sweetpi/pimatic/docs"
      else "/sweetpi/pimatic/docs/#{plugin}")


  # package.json files of plugins
  pluginPackageJson = ("../#{plugin}/package.json" for plugin in plugins)
  # and main package.json files
  bumpFiles = ["package.json"].concat pluginPackageJson

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON "package.json"
    coffeelint:
      app: [
        "*.coffee"
        "../pimatic-*/*.coffee"
        "lib/**/*.coffee"
        "test/**/*.coffee"
      ]
      options:
        no_trailing_whitespace:
          level: "ignore"
        max_line_length:
          value: 100
        indentation:
          value: 2
          level: "error"
        no_unnecessary_fat_arrows:
          level: 'ignore'
    groc: grocTasks

    "ftp-deploy": ftpTasks

    mochaTest:
      test:
        options:
          reporter: "spec"
          require: ['coffee-errors'] #needed for right line numbers in errors
        src: ["test/*"]
      # blanket is used to record coverage
      testBlanket:
        options:
          reporter: "dot"
          require: ["coverage/blanket"]
        src: ["test/*"]
      coverage:
        options:
          reporter: "html-cov"
          quiet: true
          captureFile: "coverage/coverage.html"
        src: ["test/*"]
    bump:
      options:
        files: bumpFiles
        updateConfigs: []
        commit: true
        commitMessage: "version %VERSION%"
        commitFiles: ["-a"] # '-a' for all files
        createTag: true
        tagName: "v%VERSION%"
        tagMessage: "version %VERSION%"
        push: true
        pushTo: "origin"
        gitDescribeOptions: "--tags --always --abbrev=1 --dirty=-d"


  grunt.loadNpmTasks 'grunt-bump'
  grunt.loadNpmTasks "grunt-coffeelint"
  grunt.loadNpmTasks "grunt-groc"
  grunt.loadNpmTasks "grunt-ftp-deploy"
  grunt.loadNpmTasks "grunt-mocha-test"

  # Default task(s).
  grunt.registerTask "default", ["coffeelint", "mochaTest:test", "groc"]
  grunt.registerTask "test", ["coffeelint", "mochaTest:test"]
  grunt.registerTask "coverage", ["mochaTest:testBlanket", "mochaTest:coverage"]
