module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    coffeelint: {
      app: ['*.coffee', 'backends/**/*.coffee', 'frontends/**/*.coffee',
      'lib/**/*.coffee'],
      options: {
        'no_trailing_whitespace': {
          level: 'ignore'
        },
        'max_line_length': {
          value: 100
        },
        'indentation': {
          value: 2,
          level: 'error'
        }
      }
    }
  });

  grunt.loadNpmTasks('grunt-coffeelint');

  // Default task(s).
  grunt.registerTask('default', ['coffeelint']);

};