gulp = require 'gulp'
gutil = require 'gulp-util'
coffee = require 'gulp-coffee'

gulp.task 'coffee', ->
  gulp
    .src './public/**/*.coffee'
    .pipe coffee()
    .on 'error', gutil.log
    .pipe gulp.dest './public'

gulp.task 'watch', [ 'coffee' ], ->
  gulp.watch './public/**/*.coffee', [ 'coffee' ]

gulp.task 'default', [ 'coffee', 'watch' ]
