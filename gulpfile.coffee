gulp = require 'gulp'
gutil = require 'gulp-util'
coffee = require 'gulp-coffee'

gulp.task 'copyPlayerDependencies', ->
  gulp
    .src [ './node_modules/underscore/underscore-min.js' ]
    .pipe gulp.dest './public/player/'

gulp.task 'coffee', ->
  gulp
    .src './public/**/*.coffee'
    .pipe coffee()
    .on 'error', gutil.log
    .pipe gulp.dest './public'

tasks = [ 'copyPlayerDependencies', 'coffee' ]

gulp.task 'watch', tasks, ->
  gulp.watch './public/**/*.coffee', [ 'coffee' ]

tasks = tasks.slice(0)
tasks.push 'watch'
gulp.task 'default', tasks
