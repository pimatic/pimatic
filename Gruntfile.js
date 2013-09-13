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
    },
    groc: {
      javascript: [], //file list is in the groc.json file
      options: grunt.file.readJSON('.groc.json')
    },
    'ftp-deploy': {
      build: {
        auth: {
          host: 'sweetpi.de',
          port: 21//,
          //authKey: 'key1'
        },
        src: 'docs',
        dest: '/sweetpi/sweetpi-server/docs'
      }
    }
  });

  grunt.loadNpmTasks('grunt-coffeelint');
  grunt.loadNpmTasks('grunt-groc');
  grunt.loadNpmTasks('grunt-ftp-deploy');

  // Default task(s).
  grunt.registerTask('default', ['coffeelint', 'groc']);

};