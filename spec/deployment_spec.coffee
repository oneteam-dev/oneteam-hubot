path = require 'path'
# Hubot classes
Robot = require("hubot/src/robot")
TextMessage = require("hubot/src/message").TextMessage

# Load assertion methods to this scope
chai = require 'chai'
nock = require 'nock'
sinon = require 'sinon'
{ expect } = chai

describe 'deployment', ->
  robot = null
  user = null
  adapter = null
  nockScope = null
  beforeEach (done)->
    process.env.HUBOT_GITHUB_TOKEN = 'mocha'
    process.env.HUBOT_GITHUB_ORG = 'oneteam-dev'
    process.env.EXPRESS_PORT = '0'
    do nock.disableNetConnect
    robot = new Robot null, 'mock-adapter', yes, 'TestHubot'
    robot.adapter.on 'connected', ->
      robot.loadFile path.resolve('.', 'scripts'), 'deployment.coffee'
      robot.loadFile path.resolve('.', 'scripts'), 'github-api.coffee'
      robot.loadExternalScripts ['hubot-help']
      user = robot.brain.userForId '1', {
        name: 'ngs'
        room: '#mocha'
      }
      adapter = robot.adapter
      waitForHelp = ->
        if robot.helpCommands().length > 0
          do done
        else
          setTimeout waitForHelp, 100
      do waitForHelp
    do robot.run

  afterEach ->
    robot.shutdown()
    process.removeAllListeners 'uncaughtException'

  describe 'help', ->
    it 'should have 3', (done)->
      expect(robot.helpCommands()).to.have.length 3
      do done

    it 'should parse help', (done)->
      adapter.on 'send', (envelope, strings)->
        try
          expect(strings[0]).to.equal """
          TestHubot deploy <repo> to <env> - deploy <repo> to the specified environment
          TestHubot help - Displays all of the help commands that Hubot knows about.
          TestHubot help <query> - Displays all help commands that match <query>.
          """
          do done
        catch e
          done e
      adapter.receive new TextMessage user, 'TestHubot help'

  describe 'deploy', ->
    it 'should say I dont know', (done) ->
      adapter.on 'reply', (envelope, strings)->
        try
          expect(strings[0]).to.equal "I don't know such an environment: `hoge`."
          do done
        catch e
          done e
      adapter.receive new TextMessage user, 'TestHubot deploy oneteam-api to hoge'

    it 'should reply up to date', (done) ->
      sinon.stub(robot.getGitHubApi().repos, 'compareCommits').callsArgWith 1, null, { commits: [] }
      adapter.on 'send', (envelope, strings) ->
        try
          expect(strings[0]).to.equal 'Creating pull request: `master` to `deployment/production` of https://github.com/oneteam-dev/oneteam-api'
        catch e
          done e
      adapter.on 'reply', (envelope, strings) ->
        try
          expect(strings[0]).to.equal 'production environment is up to date.'
          do done
        catch e
          done e
      adapter.receive new TextMessage user, 'TestHubot deploy oneteam-api to production'

    testDeploy = (head, base, env) ->
      (done) ->
        sinon.stub(robot.getGitHubApi().repos, 'compareCommits').callsArgWith 1, null, {
          commits: [
            {
              sha: "1000000000000000000000000000000000000000"
              commit:
                message: 'GH-100: commit 1'
              author:
                login: 'user01'
              committer:
                login: 'user02'
              parents: [{}]
            }
            {
              sha: "2000000000000000000000000000000000000000"
              commit:
                message: 'commit 2 #100 yo'
              author: {}
              committer:
                login: 'user03'
              parents: [{}]
            }
            {
              sha: "3000000000000000000000000000000000000000"
              commit:
                message: 'GH-102: commit 3 #101'
              author:
                login: 'user02'
              committer:
                login: 'user03'
              parents: [{}]
            }
            {
              sha: "3000000000000000000000000000000000000000"
              commit:
                message: 'commit 3'
              author:
                login: 'user02'
              committer:
                login: 'user03'
              parents: [{}]
            }
            {
              sha: "4000000000000000000000000000000000000000"
              commit:
                message: "Merge pull request #1234 from oneteam-dev/#{head}\n\n2015.07.15 oneteam-api staging deployment by cronbot"
              author:
                login: 'user02'
              committer:
                login: 'user03'
              parents: [{}, {}]
            }
            {
              sha: "5000000000000000000000000000000000000000"
              commit:
                message: "Merge pull request #1235 from oneteam-dev/#{base}\n\n2015.07.15 oneteam-api production deployment by cronbot"
              author:
                login: 'user02'
              committer:
                login: 'user03'
              parents: [{}, {}]
            }
          ]
        }
        sinon.stub robot.getGitHubApi().issues, 'getRepoIssue', (param, callback) ->
          callback null, title: "Issue #{param.number}"
        sinon.stub robot.getGitHubApi().pullRequests, 'create', (param, callback) ->
          callback null, html_url: 'https://github.com/octocat/Hello-World/pull/1347'
        count = 0
        adapter.on 'send', (envelope, strings) ->
          try
            expect(strings[0]).to.equal [
              "Creating pull request: `#{head}` to `#{base}` of https://github.com/oneteam-dev/oneteam-api\n4 updates are going to be deployed:\n- user01: GH-100: commit 1\n- user03: commit 2 #100 yo\n- user02: GH-102: commit 3 #101\n- user02: commit 3"
              "Created pull request https://github.com/octocat/Hello-World/pull/1347\nContinue deployment by merging manually or close to cancel.\nYou can check build status on https://circleci.com/gh/oneteam-dev/oneteam-api/tree/#{encodeURIComponent base}"
            ][count++]
            do done if count == 2
          catch e
            console.error e
            done e
        adapter.receive new TextMessage user, "TestHubot deploy oneteam-api to #{env}"

    it 'should create a pull request for staging', testDeploy('master', 'deployment/staging', 'staging')
    it 'should create a pull request for production', testDeploy('deployment/staging', 'deployment/production', 'production')
