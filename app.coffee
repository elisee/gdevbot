config = require './config'
utils = require './lib/utils'
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
    backend.createProject projectId, user, callback
    return

  role = switch command.type
    # These commands require admin privileges
    when 'allow', 'deny', 'cover', 'publish', 'unpublish', 'destroy' then 'admin'
    else 'member'

  backend.getProject projectId, user, role, (err, project) ->
    return callback err if err?

    switch command.type
      when 'cover'
        backend.setCover project, commands.url, callback

      when 'publish'
        backend.publish project, callback

      when 'unpublish'
        backend.unpublish project, callback

      when 'allow'
        backend.addMembers project, command.members, callback

      when 'deny'
        backend.removeMembers project, command.memberIds, callback

      when 'import'
        backend.importAsset project, command.name, command.url, callback

      when 'script'
        backend.addScript project, command.name, command.content, callback

      when 'new actor'
        backend.createActor project, command.name, command.parentName, callback

      when 'add'
        backend.addComponent project, command.actorName, command.assetName, callback

      when 'remove'
        backend.removeComponent project, command.actorName, command.assetName, callback

      when 'reparent'
        backend.reparentActor project, command.name, command.parentName, callback

      else
        callback new error 'No such command'

    return

  return


logTweetFail = (err) ->
  return if ! err?
  utils.botlog "Could not tweet:\n#{JSON.stringify(err, null, 2)}"

tweetCommandFailed = (username, reason, replyTweetId, callback) ->
  msg = "@#{username} ERR #{reason}\n#{replyTweetId.slice(-5)}"

  if ! config.twitter.enableReplies
    utils.botlog "Would have tweeted: #{msg}"
    return callback null

  twitter.statuses 'update', { status: msg, in_reply_to_status_id: replyTweetId }, config.twitter.accessToken, config.twitter.accessTokenSecret, (err) ->
    err.tweet = { type: 'failure', reason, replyTweetId } if err?
    callback err

tweetCommandSuccess = (username, projectId, replyTweetId, callback) ->
  msg = "@#{username} OK #{baseURL}/p/#{projectId}?#{replyTweetId.slice(-5)}"

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
    return tweetCommandFailed data.user.screen_name, err.message, replyTweetId, logTweetFail if err?

    # If no command has been generated, just return
    return if ! command?

    executeCommand command, projectId, data.user, (err) ->
      return tweetCommandFailed data.user.screen_name, err.message, replyTweetId, logTweetFail if err?
      tweetCommandSuccess data.user.screen_name, projectId, replyTweetId, logTweetFail

    return

endCallback = ->
  utils.botlog "Disconnected, somehow. Reconnecting."
  twitter.getStream 'userstream', {}, config.twitter.accessToken, config.twitter.accessTokenSecret, dataCallback, endCallback

twitter.getStream 'userstream', {}, config.twitter.accessToken, config.twitter.accessTokenSecret, dataCallback, endCallback
utils.botlog "Started."

# Web server
express = require 'express'
require 'express-expose'
fs = require 'fs'
path = require 'path'

app = express()
app.set 'view engine', 'jade'

app.use '/images/emoji', express.static __dirname + '/public/images/emoji', { maxAge: 1000 * 3600 * 24 }
app.use express.static __dirname + '/public'
app.use require('connect-slashes') false

app.locals.botUsername = config.twitter.username

emojisByShortcode =
  ":sunrise:":                        utf8: 0x1f305,      desc: "Once"
  ":curly_loop:":                     utf8: 0x27b0,       desc: "Always"

  ":penguin:":                        utf8: 0x1f427,      desc: "Self"
  ":baggage_claim:":                  utf8: 0x1f6c4,      desc: "Set value"
  ":key:":                            utf8: 0x1f511,      desc: "Property"
  ":scissors:":                       utf8: 0x2702,       desc: "End expression"

  ":triangular_flag_on_post:":        utf8: 0x1f6a9,      desc: "Position"
  ":car:":                            utf8: 0x1f697,      desc: "Move"
  ":o:":                              utf8: 0x2b55,       desc: "Angle"
  ":arrows_clockwise:":               utf8: 0x1f503,      desc: "Rotate"

  ":question:":                       utf8: 0x2753,       desc: "Condition"
  ":twisted_rightwards_arrows:":      utf8: 0x1f500,      desc: "'Not' operator"
  ":fast_forward:":                   utf8: 0x23e9,       desc: "Block start"
  ":rewind:":                         utf8: 0x23ea,       desc: "Block end"

  ":hand:":                           utf8: 0x270b,       desc: "Touch position"
  ":wave:":                           utf8: 0x1f44b,      desc: "Touch movement"
  ":point_up_2:":                     utf8: 0x1f446,      desc: "Touch started"
  ":point_up:":                       utf8: 0x261d,       desc: "Touch ended"

  ":random:":                         utf8: 0x1f3b2,      desc: "Random"

require 'string.fromcodepoint'
app.locals.imgEmoji = (shortcode) ->
  emoji = emojisByShortcode[shortcode]
  """<img src="images/emoji/#{emoji.utf8.toString(16)}.png", alt="#{String.fromCodePoint(emoji.utf8)}", title="#{emoji.desc}" data-shortcode="#{shortcode}">"""

app.locals.menu = [
  { path: '/', title: 'Home' },
  { path: '/games', title: 'Games' },
  { path: '/commands', title: 'Commands' },
  { path: '/emoji', title: 'Emoji code' },
]

app.use (req, res, next) -> res.locals.path = req.path; next()

app.get '/', (req, res) -> res.render 'index'
app.get '/games', (req, res) -> res.render 'games', { games: backend.publishedGames }
app.get '/commands', (req, res) -> res.render 'commands'
app.get '/emoji', (req, res) -> res.render 'emoji'

app.get '/p/:projectId', (req, res) ->
  fs.readdir path.join(__dirname, 'public', 'projects', req.params.projectId.toLowerCase(), 'assets'), (err, assets) ->
    return res.render 'gameNotFound', projectId: req.params.projectId if err?

    fs.readFile path.join(__dirname, 'public', 'projects', req.params.projectId.toLowerCase(), 'actors.json'), encoding: 'utf8', (err, actorsJSON) ->
      return console.log err.stack if err?

      actors = JSON.parse actorsJSON

      if assets.length == 0 or actors.length == 0 or (actors[0].children.length == 0 and actors[0].components.length == 0)
        return res.render 'newGame', projectId: req.params.projectId, assets: assets, actors: actors

      project =
        projectId: req.params.projectId
        assets: assets
        actors: actors

      res.expose project
      res.render 'game', projectId: req.params.projectId

app.listen config.internalPort
