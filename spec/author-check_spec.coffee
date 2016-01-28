path = require 'path'
fs = require 'fs'
# Hubot classes
Robot = require("hubot/src/robot")
TextMessage = require("hubot/src/message").TextMessage

# Load assertion methods to this scope
chai = require 'chai'
nock = require 'nock'
sinon = require 'sinon'
{ expect } = chai

describe 'author-check', ->
  robot = null
  user = null
  adapter = null
  mockResponse = (fixture)->
    body = fs.readFileSync path.resolve(__dirname, 'fixtures', "issue-body-#{fixture}.md"), 'utf8'
    sinon.stub(robot.getGitHubApi().pullRequests, 'getAll').callsArgWith 1, null, [
      {
        body: 'hoge'
        title: 'hotfix hoge'
        html_url: 'https://github.com/oneteam-dev/oneteam-api/pull/1205'
      }
      {
        body: body
        title: '2014.06.17 staging deployment by ngs'
        html_url: 'https://github.com/oneteam-dev/oneteam-api/pull/1206'
      }
    ]


  beforeEach (done)->
    process.env.HUBOT_GITHUB_TOKEN = 'mocha'
    process.env.HUBOT_GITHUB_ORG = 'oneteam-dev'
    nock.disableNetConnect()
    robot = new Robot null, 'mock-adapter', yes, 'TestHubot'
    robot.adapter.on 'connected', ->
      robot.loadFile path.resolve('.', 'scripts'), 'author-check.coffee'
      robot.loadFile path.resolve('.', 'scripts'), 'github-api.coffee'
      robot.loadExternalScripts ['hubot-help']
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
          TestHubot ask checking <repo> on {staging,production} - Please check operation of <env> env.
          TestHubot help - Displays all of the help commands that Hubot knows about.
          TestHubot help <query> - Displays all help commands that match <query>.
          """]
          do done
        catch e
          done e
      adapter.receive new TextMessage user, 'TestHubot help'

    describe 'ask staging', ->
      describe 'has unchecked', ->
        beforeEach (done)->
          mockResponse 'incomplete'
          do done
        it 'should send message', (done)->
          count = 0
          adapter.on 'send', (envelope, strings)->
            try
              expect(strings[0]).to.equal 'Please check operation in staging env :bow: <@user02> <@user03> <@kon-chan> <@qubo> https://github.com/oneteam-dev/oneteam-api/pull/1206'
              do done
            catch e
              done e
          adapter.receive new TextMessage user, 'testhubot  ask   checking  oneteam-api   on   staging  '

      describe 'all checked', ->
        beforeEach (done)->
          mockResponse 'complete'
          do done
        it 'should send message', (done)->
          count = 0
          adapter.on 'send', (envelope, strings)->
            try
              expect(strings).to.deep.equal [[
                '<!here> Completed operation check in staging env :white_check_mark: https://github.com/oneteam-dev/oneteam-api/pull/1206'
                'cronbot remove job with message testhubot  ask   checking  oneteam-api   on   staging  '
              ][count++]]
              do done if count == 2
            catch e
              console.error e
              done e
          adapter.receive new TextMessage user, 'testhubot  ask   checking  oneteam-api   on   staging  '
