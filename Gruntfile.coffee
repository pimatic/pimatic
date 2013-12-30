module.exports = (grunt) ->

  # all node_modules:
  modules = require("fs").readdirSync "./node_modules"
  # just the pimatic-* modules:
  plugins = (module for module in modules when module.match(/^pimatic-.*/)?)

  # files for generating documentation:
  grocFiles = [
    "./README.md"
    "./startup.coffee"
    "./config-shema.coffee"
    "./lib/*.coffee"
  ]
  for plugin in plugins
    grocFiles.push "./node_modules/#{plugin}/README.md"
    grocFiles.push "./node_modules/#{plugin}/*.coffee"

  # package.json files of plugins
  pluginPackageJson = ("node_modules/#{plugin}/package.json" for plugin in plugins)
  # and main package.json files
  bumpFiles = ["package.json"].concat pluginPackageJson

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON "package.json"
    coffeelint:
      app: [
        "*.coffee"
        "node_modules/pimatic-*/*.coffee"
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

    groc:
      files: grocFiles
      options: 
        root: "."
        out: "docs"
        "repository-url": "https://github.com/pimatic/pimatic"
        strip: false

    "ftp-deploy":
      build:
        auth:
          host: "sweetpi.de"
          port: 21
        authKey: 'sweetpi.de'
        src: "docs"
        dest: "/sweetpi/pimatic/docs"

    mochaTest:
      test:
        options:
          reporter: "spec"
          require: ['coffee-errors'] #needed for right line numbers in errors
        src: ["test/**/*"]
      # blanket is used to record coverage
      testBlanket:
        options:
          reporter: "dot"
          require: ["coverage/blanket"]
        src: ["test/**/*"]
      coverage:
        options:
          reporter: "html-cov"
          quiet: true
          captureFile: "coverage/coverage.html"

        src: ["test/**/*."]
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
        pushTo: "upstream"
        gitDescribeOptions: "--tags --always --abbrev=1 --dirty=-d"


  grunt.loadNpmTasks 'grunt-bump'
  grunt.loadNpmTasks "grunt-coffeelint"
  grunt.loadNpmTasks "grunt-groc"
  grunt.loadNpmTasks "grunt-ftp-deploy"
  grunt.loadNpmTasks "grunt-mocha-test"
  grunt.registerTask "publish-plugins", "publish all pimatic-plugins", ->
    done = @async()
    cwd = process.cwd()
    plugins = require("fs").readdirSync("./node_modules")
    require("async").eachSeries plugins, ((file, cb) ->
      grunt.log.writeln "publishing: " + file
      process.chdir cwd + "/node_modules/" + file
      child = grunt.util.spawn(
        opts:
          stdio: "inherit"
        cmd: "npm"
        args: ["publish"]
      , (err) ->
        console.log err.message  if err
        cb()
      )
    ), (err) ->
      process.chdir cwd
      done()


  # Default task(s).
  grunt.registerTask "default", ["coffeelint", "mochaTest:test", "groc"]
  grunt.registerTask "test", ["coffeelint", "mochaTest:test"]
  grunt.registerTask "coverage", ["mochaTest:testBlanket", "mochaTest:coverage"]
