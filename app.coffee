config = require './config'
utils = require './lib/utils'
emoji = require './lib/emoji'
backend = require './lib/backend'

Entities = require('html-entities').AllHtmlEntities
entities = new Entities()

twitterAPI = require 'node-twitter-api'
twitter = new twitterAPI config.twitter

baseURL = "http://#{config.domain}"
baseURL += ":#{config.publicPort}" if config.publicPort != 80


parseCommand = (text, tweet, callback) ->
  command = {}

  tokens = text.split ' '
  command.type = tokens[0]

  if tweet.entities?.user_mentions?.length != 1 and tokens[0] not in ['allow', 'deny']
    # Ignore tweets with multiple mentions except for specific commands
    return callback null, null
  
  switch tokens[0]
    when 'create'
      return callback new Error "Invalid arguments" if tokens.length != 1

    when 'cover'
      return callback new Error "Invalid arguments" if tokens.length != 2

      command.url = tokens[1]

    when 'publish'
      return callback new Error "Invalid arguments" if tokens.length != 1

    when 'unpublish'
      return callback new Error "Invalid arguments" if tokens.length != 1

    when 'allow'
      return callback new Error "Invalid arguments" if ! tweet.entities?.user_mentions? or tweet.entities.user_mentions.length < 2

      command.members = []

      for mention in tweet.entities.user_mentions
        continue if mention.id_str == config.twitter.userId
        command.members.push id: mention.id_str, cachedUsername: mention.screen_name

    when 'deny'
      return callback new Error "Invalid arguments" if ! tweet.entities?.user_mentions? or tweet.entities.user_mentions.length < 2

      command.memberIds = []

      for mention in tweet.entities.user_mentions
        continue if mention.id_str == config.twitter.userId
        command.memberIds.push mention.id_str

    when 'import'
      return callback new Error "Invalid arguments" if tokens.length != 4

      command.name = tokens[1]
      return callback new Error "Expected 'from' after name" if tokens[2] != 'from'
      command.url = tokens[3]

    when 'script'
      return callback new Error "Expected a script after name" if tokens.length < 3

      command.name = tokens[1]
      command.content = tokens.slice(2).join ' '

    when 'new'
      return callback new Error "Invalid arguments" if tokens.length < 3
      return callback new Error "Expected 'actor' after 'new'" if tokens[1] != 'actor'
      command.type += " #{tokens[1]}"

      command.name = tokens[2]

      if tokens.length == 5
        return callback new Error "Expected 'parent' after actor name" if tokens[3] != 'parent'
        command.parentName = tokens[4]
      else
        return callback new Error "Invalid arguments" if tokens.length != 3

    when 'add'
      return callback new Error "Invalid arguments" if tokens.length != 4

      command.assetName = tokens[1]
      return callback new Error "Expected 'to' after asset name" if tokens[2] != 'to'
      command.actorName = tokens[3]

    when 'remove'
      return callback new Error "Invalid arguments" if tokens.length != 4

      command.assetName = tokens[1]
      return callback new Error "Expected 'from' after asset name" if tokens[2] != 'from'
      command.actorName = tokens[3]

    when 'reparent'
      return callback new Error "Invalid arguments" if tokens.length != 4

      command.name = tokens[1]
      return callback new Error "Expected 'to' after actor name" if tokens[2] != 'to'
      command.parentName = tokens[3]

    else
      return callback new Error "No such command"

  callback null, command


executeCommand = (command, projectId, user, callback) ->

  if command.type == 'create'
    backend.createProject projectId, user, (err) ->
      return callback err if err?
      callback null, "Project created"
    return

  role = switch command.type
    # These commands require admin privileges
    when 'allow', 'deny', 'cover', 'publish', 'unpublish', 'destroy' then 'admin'
    else 'member'

  backend.getProject projectId, user, role, (err, project) ->
    return callback err if err?

    switch command.type
      when 'cover'
        backend.setCover project, command.url, (err) ->
          return callback err if err?
          callback null, "Cover updated"

      when 'publish'
        backend.publish project, (err) ->
          return callback err if err?
          callback null, "Published on the store"

      when 'unpublish'
        backend.unpublish project, (err) ->
          return callback err if err?
          callback null, "Unpublished from the store"

      when 'allow'
        backend.addMembers project, command.members, (err) ->
          return callback err if err?
          callback null, "New member(s) added"

      when 'deny'
        backend.removeMembers project, command.memberIds, (err) ->
          return callback err if err?
          callback null, "Member(s) removed"

      when 'import'
        backend.importAsset project, command.name, command.url, (err) ->
          return callback err if err?
          callback null, "Asset imported"

      when 'script'
        backend.addScript project, command.name, command.content, (err) ->
          return callback err if err?
          callback null, "Script added or updated"

      when 'new actor'
        backend.createActor project, command.name, command.parentName, (err) ->
          return callback err if err?
          callback null, "New actor created"

      when 'add'
        backend.addComponent project, command.actorName, command.assetName, (err) ->
          return callback err if err?
          callback null, "Asset added to actor"

      when 'remove'
        backend.removeComponent project, command.actorName, command.assetName, (err) ->
          return callback err if err?
          callback null, "Asset removed from actor"

      when 'reparent'
        backend.reparentActor project, command.name, command.parentName, (err) ->
          return callback err if err?
          callback null, "Actor reparented"

      else
        callback new Error "No such command"

    return

  return


logTweetFail = (err) ->
  return if ! err?
  utils.botlog "Could not tweet:\n#{JSON.stringify(err, null, 2)}"

tweetReply = (username, text, replyTweetId, callback) ->
  msg = "@#{username} #{text}"

  if ! config.twitter.enableReplies
    utils.botlog "Would have tweeted: #{msg}"
    return callback null

  twitter.statuses 'update', { status: msg, in_reply_to_status_id: replyTweetId }, config.twitter.accessToken, config.twitter.accessTokenSecret, (err) ->
    err.tweet = { type: 'success', replyTweetId } if err?
    callback err

dataCallback = (err, data, chunk, response) ->
  return utils.botlog JSON.stringify err, null, 2 if err?

  # utils.debuglog JSON.stringify data, null, 2

  # Ignore non-tweets
  return if ! data.text? or ! data.user?
  # Ignore tweets without a screen name (can that ever happen?) and tweets from the bot itself
  return if ! data.user.screen_name? or data.user.id_str == config.twitter.userId
  # Ignore tweets not mentioning the bot
  return if data.text.indexOf("@#{config.twitter.username}") == -1
  # Ignore retweets
  return if data.retweeted_status?
  # Ignore tweets not containing a single project hashtag
  return if data.entities?.hashtags?.length != 1 or data.text.split('#').length - 1 > 1

  utils.botlog "#{data.user.screen_name}: #{data.text}"

  commandText = data.text

  # Replace any Twitter photo link by the actual image URL
  if data.entities.media? and data.entities.media.length == 1 and data.entities.media[0].type == 'photo'
    photo = data.entities.media[0]
    commandText = commandText.slice(0, photo.indices[0]) + photo.media_url + commandText.slice(photo.indices[1])

  # Remove the bot mention
  botMention = data.entities.user_mentions[0]
  botMentionIndex = commandText.indexOf '@'
  commandText = commandText.slice(0, botMentionIndex) + commandText.slice(botMentionIndex + 1 + botMention.screen_name.length)

  # Remove the project name
  projectId = data.entities.hashtags[0].text
  projectHashtagIndex = commandText.indexOf '#'
  commandText = commandText.slice(0, projectHashtagIndex) + commandText.slice(projectHashtagIndex + 1 + projectId.length)

  # Decode HTML entities (Twitter does return some)
  # see https://dev.twitter.com/issues/858
  commandText = entities.decode commandText

  # Collapse multiple spaces
  commandText = commandText.trim().replace(/\s{2,}/g, ' ')
  utils.botlog "[#{projectId}] #{data.user.screen_name}: #{commandText}"

  replyTweetId = data.id_str

  parseCommand commandText, data, (err, command) ->
    return logTweet projectId, data, false, err.message if err?

    # If no command has been generated, just return
    return if ! command?

    executeCommand command, projectId, data.user, (err, message) ->
      success = ! err?
      response = if ! success then err.message else message

      logTweet projectId, data, success, response

      if command.type == 'create'
        tweetReply data.user.screen_name, "Here's your new project! #{emoji.char(':thumbsup:')} #{baseURL}/p/#{projectId}/edit", replyTweetId, logTweetFail
      else if command.type == 'publish'
        tweetReply data.user.screen_name, "Here's your game link! #{emoji.char(':heart:')} #{baseURL}/p/#{projectId}", replyTweetId, logTweetFail

      return
    return

endCallback = ->
  utils.botlog "Disconnected, somehow. Reconnecting."
  twitter.getStream 'userstream', {}, config.twitter.accessToken, config.twitter.accessTokenSecret, dataCallback, endCallback

twitter.getStream 'userstream', {}, config.twitter.accessToken, config.twitter.accessTokenSecret, dataCallback, endCallback
utils.botlog "Started."

logTweet = (projectId, tweet, success, response) ->
  backend.logTweet projectId, tweet, success, response, (err, logEntry) ->
    return if err?
    io.to(projectId.toLowerCase()).emit 'projectLogEntry', logEntry

# Web server
express = require 'express'
require 'express-expose'
fs = require 'fs'
path = require 'path'

app = express()
server = require('http').Server app
io = require('socket.io')(server)

io.on 'connection', (socket) ->
  socket.on 'subscribeProjectLog', (projectId) ->
    backend.getProjectLog projectId, 100, (err, log) ->
      return socket.disconnect() if err?
      socket.emit 'projectLog', log
      socket.join projectId.toLowerCase()


app.set 'view engine', 'jade'

app.use '/images/emoji', express.static __dirname + '/public/images/emoji', { maxAge: 1000 * 3600 * 24 }
app.use express.static __dirname + '/public'
app.use require('connect-slashes') false

app.locals.botUsername = config.twitter.username
app.locals.imgEmoji = emoji.img

app.locals.menu = [
  { path: '/', title: 'Home' },
  { path: '/games', title: 'Games' },
  { path: '/commands', title: 'Commands' },
  { path: '/emoji', title: 'Emoji code' }
]

app.use (req, res, next) -> res.locals.path = req.path; next()

app.get '/', (req, res) -> res.render 'index'
app.get '/games', (req, res) -> res.render 'games', { games: backend.publishedGames }
app.get '/commands', (req, res) -> res.render 'commands'
app.get '/emoji', (req, res) -> res.render 'emoji'

getProject = (projectId, callback) ->
  fs.readdir path.join(__dirname, 'public', 'projects', projectId.toLowerCase(), 'assets'), (err, assets) ->
    return callback err if err?

    fs.readFile path.join(__dirname, 'public', 'projects', projectId.toLowerCase(), 'actors.json'), encoding: 'utf8', (err, actorsJSON) ->
      return callback err if err?

      actors = JSON.parse actorsJSON

      callback null,
        id: projectId
        assets: assets
        actors: actors

app.get '/p/:projectId', (req, res) ->
  getProject req.params.projectId, (err, project) ->
    return res.render 'gameNotFound', projectId: project.id if err?

    res.expose { project }
    res.render 'game', projectId: project.id

app.get '/p/:projectId/edit', (req, res) ->
  getProject req.params.projectId, (err, project) ->
    return res.render 'gameNotFound', projectId: project.id if err?

    if project.assets.length == 0 or project.actors.length == 0 or (project.actors[0].children.length == 0 and project.actors[0].components.length == 0)
      res.expose { project }
      res.render 'newGame', projectId: project.id, assets: project.assets, actors: project.actors, showSidebar: true
    else
      res.expose { project }
      res.render 'game', projectId: project.id, showSidebar: true

app.get '/p/:projectId/log.json', (req, res) ->
  backend.getProjectLog req.params.projectId, 100, (err, log) ->
    return res.send 500 if err?
    res.json log

server.listen config.internalPort
