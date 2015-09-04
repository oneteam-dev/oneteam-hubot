path = require 'path'
# Hubot classes
Robot = require("hubot/src/robot")
TextMessage = require("hubot/src/message").TextMessage

# Load assertion methods to this scope
chai = require 'chai'
nock = require 'nock'
sinon = require 'sinon'
{ expect } = chai

describe 'dockerhub webhook', ->
  robot = null
  user = null
  adapter = null
  nockScope = null
  beforeEach (done)->
    process.env.EXPRESS_PORT = '18080'
    do nock.disableNetConnect
    nock.enableNetConnect '127.0.0.1'
    robot = new Robot null, 'mock-adapter', yes, 'TestHubot'
    robot.adapter.on 'connected', ->
      robot.loadFile path.resolve('.', 'scripts'), 'dockerhub-webhook.coffee'
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

  it 'handles push data event', (done) ->
    adapter.on 'send', (envelope, strings)->
      try
        expect(strings[0]).to.equal """
        New image for `oneteam/base-ubuntu` was pushed by oneteamadmin https://registry.hub.docker.com/u/oneteam/base-ubuntu/
        """
        do done
      catch e
        done e

    data =
      'push_data':
        'pushed_at': 1441321087
        'images': null
        'pusher': 'oneteamadmin'
      'callback_url': 'https://registry.hub.docker.com/u/oneteam/base-ubuntu/hook/224fh024ja54ji0dhej14c251djhbg5/'
      'repository':
        'status': 'Active'
        'description': 'Base Ubuntu Image'
        'is_trusted': false
        'full_description': ''
        'repo_url': 'https://registry.hub.docker.com/u/oneteam/base-ubuntu/'
        'owner': 'oneteam'
        'is_official': false
        'is_private': false
        'name': 'base-ubuntu'
        'namespace': 'oneteam'
        'star_count': 1
        'comment_count': 0
        'date_created': 1441203219
        'repo_name': 'oneteam/base-ubuntu'

    do robot.http('http://127.0.0.1:18080/webhooks/dockerhub')
    .header('Content-Type', 'application/json')
    .post JSON.stringify data
