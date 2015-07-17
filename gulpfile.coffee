gulp       = require 'gulp'
gutil      = require 'gulp-util'
coffee     = require 'gulp-coffee'
mocha      = require 'gulp-mocha'
watch      = require 'gulp-watch'
coffeelint = require 'gulp-coffeelint'
watching   = no

require 'coffee-script/register'

gulp.task 'default', ['mocha']

coffeePipes = (pipe)->
  pipe
    .pipe(coffeelint max_line_length: { level: 'ignore' })
    .pipe(coffeelint.reporter())
    .pipe(coffee(bare: yes)
      .pipe(mocha reporter: process.env.MOCHA_REPORTER || 'nyan')
      .on('error', ->
        if watching
          @emit 'end'
        else
          process.exit 1
      ))

gulp.task 'mocha', ->
  coffeePipes(gulp.src('spec/*.coffee'))
    .once('end', -> process.exit() )

gulp.task 'watch', ->
  watching = yes
  watch ['scripts/*.coffee', 'spec/*.coffee'], ->
    coffeePipes(gulp.src('spec/*.coffee'))
