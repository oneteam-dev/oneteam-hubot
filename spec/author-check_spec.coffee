path = require 'path'
fs = require 'fs'
# Hubot classes
Robot = require("hubot/src/robot")
TextMessage = require("hubot/src/message").TextMessage

# Load assertion methods to this scope
chai = require 'chai'
nock = require 'nock'
{ expect } = chai

mockResponse = (fixture, status = 200)->
  body = fs.readFileSync path.resolve(__dirname, 'fixtures', "issue-body/#{fixture}.md"), 'utf8'
  nock('https://api.github.com')
    .filteringPath(-> '/issues' )
    .get('/issues')
    .reply status, [
      { title: 'test 1' }
      { title: 'test 2' }
      {
        body: body
        title: '2014.06.17 broadpeak production deployment by Deploy Notifier'
        html_url: 'https://github.com/kaizenplatform/planbcd/pull/1205'
      }
      {
        body: body
        title: '2014.06.17 k2 production deployment by Deploy Notifier'
        html_url: 'https://github.com/kaizenplatform/planbcd/pull/1205'
      }
    ]

describe 'author-check', ->
  robot = null
  user = null
  adapter = null
  beforeEach (done)->
    process.env.HUBOT_GITHUB_TOKEN = 'mocha'
    process.env.HUBOT_GITHUB_ORG = 'kaizenplatform'
    nock.disableNetConnect()
    robot = new Robot null, 'mock-adapter', yes, 'TestHubot'
    robot.adapter.on 'connected', ->
      robot.loadFile path.resolve('.', 'scripts'), 'author-check.coffee'
      hubotScripts = path.resolve 'node_modules', 'hubot', 'src', 'scripts'
      user = robot.brain.userForId '1', {
        name: 'ngs'
        room: '#mocha'
      }
      adapter = robot.adapter
      do waitForHelp = ->
        if robot.helpCommands().length > 0
          do done
        else
          setTimeout waitForHelp, 100
    do robot.run

  afterEach ->
    robot.server.close()
    nock.cleanAll()
    robot.shutdown()
    process.removeAllListeners 'uncaughtException'

  xdescribe 'no', ->
    describe 'help', ->
      it 'should have 3', (done)->
        expect(robot.helpCommands()).to.have.length 3
        do done

      it 'should parse help', (done)->
        adapter.on 'send', (envelope, strings)->
          ## Prefix bug with parseHelp
          ## https://github.com/github/hubot/pull/712
          try
            expect(strings).to.deep.equal ["""
            TestHubot ask checking <repo> on {qa,production} - <env> 環境での動作確認をお願いいたします。
            TestHubot help - Displays all of the help commands that TestHubot knows about.
            TestHubot help <query> - Displays all help commands that match <query>.
            """]
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'TestHubot help'

    describe 'ask qa', ->
      describe 'has unchecked', ->
        beforeEach (done)->
          mockResponse 'has-unchecked'
          do done
        [
          'testhubot  ask   checking   planbcd   on   qa  '
        ].forEach (msg)->
          describe msg, ->
            it 'should send message', (done)->
              adapter.on 'send', (envelope, strings)->
                try
                  expect(strings).to.deep.equal ['QA 環境での動作確認をお願いいたします。 <@ngs> <@ku> <@yoshiakisudo> <@keiji> <@nishiya> <@jimbo> <@dtaniwaki> <@mdoi> <@iandeth> https://github.com/kaizenplatform/planbcd/pull/1205']
                  do done
                catch e
                  done e
              adapter.receive new TextMessage user, msg

      describe 'all checked', ->
        beforeEach (done)->
          mockResponse 'all-checked'
          do done
        [
          ['testhubot  ask   checking   planbcd     on   qa  ', 'k2'       ]
          ['testhubot  ask   checking   k2          on   qa  ', 'k2'       ]
          ['testhubot  ask   checking   broadpeak   on   qa  ', 'broadpeak']
        ].forEach ([msg, repo])->
          describe msg, ->
            it 'should send message', (done)->
              count = 0
              adapter.on 'send', (envelope, strings)->
                try
                  expect(strings).to.deep.equal [[
                    'QA 環境の動作確認が完了しました。 https://github.com/kaizenplatform/planbcd/pull/1205'
                    "cronbot remove job with message kaizenbot ask checking #{repo} on qa"
                  ][count++]]
                  do done if count == 2
                catch e
                  done e
              adapter.receive new TextMessage user, msg

    describe 'ask production', ->
      describe 'has unchecked', ->
        beforeEach (done)->
          mockResponse 'has-unchecked'
          do done
        [
          'testhubot  ask   checking   planbcd   on   production  '
        ].forEach (msg)->
          describe msg, ->
            it 'should send message', (done)->
              adapter.on 'send', (envelope, strings)->
                try
                  expect(strings).to.deep.equal ['本番環境での動作確認をお願いいたします。 <@keiji> <@ngs> <@ku> <@dtaniwaki> <@mdoi> https://github.com/kaizenplatform/planbcd/pull/1205']
                  do done
                catch e
                  done e
              adapter.receive new TextMessage user, msg

      describe 'all checked', ->
        beforeEach (done)->
          mockResponse 'all-checked'
          do done
        [
          ['testhubot  ask   checking   planbcd     on   production  ', 'k2'       ]
          ['testhubot  ask   checking   k2          on   production  ', 'k2'       ]
          ['testhubot  ask   checking   broadpeak   on   production  ', 'broadpeak']
        ].forEach ([msg, repo])->
          describe msg, ->
            it 'should send message', (done)->
              count = 0
              adapter.on 'send', (envelope, strings)->
                try
                  expect(strings).to.deep.equal [[
                    '本番環境の動作確認が完了しました。 https://github.com/kaizenplatform/planbcd/pull/1205'
                    "cronbot remove job with message kaizenbot ask checking #{repo} on production"
                  ][count++]]
                  do done if count == 2
                catch e
                  done e
              adapter.receive new TextMessage user, msg
