gulp = require 'gulp'
gutil = require 'gulp-util'
coffee = require 'gulp-coffee'

gulp.task 'copyPlayerDependencies', ->
  gulp
    .src [ './node_modules/underscore/underscore-min.js' ]
    .pipe gulp.dest './public/player/'

gulp.task 'copyPlaygroundDependencies', ->
  gulp
    .src [ './node_modules/js-beautify/js/lib/beautify.js' ]
    .pipe gulp.dest './public/js/'

gulp.task 'coffee', ->
  gulp
    .src './public/**/*.coffee'
    .pipe coffee()
    .on 'error', gutil.log
    .pipe gulp.dest './public'

tasks = [ 'copyPlayerDependencies', 'copyPlaygroundDependencies', 'coffee' ]

gulp.task 'watch', tasks, ->
  gulp.watch './public/**/*.coffee', [ 'coffee' ]

gulp.task 'default', tasks
