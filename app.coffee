config = require './config'
utils = require './lib/utils'
backend = require './lib/backend'

twitterAPI = require 'node-twitter-api'
twitter = new twitterAPI config.twitter

baseURL = "http://#{config.domain}"
baseURL += ":#{config.publicPort}" if config.publicPort != 80


parseCommand = (text, callback) ->
  command = {}

  tokens = text.split ' '
  command.type = tokens[0]

  switch tokens[0]
    when 'import'
      return callback new Error "Invalid arguments" if tokens.length != 4

      command.name = tokens[1]
      return callback new Error "Syntax error, expected 'from'" if tokens[2] != 'from'
      command.url = tokens[3]

    when 'script'
      return callback new Error "Expected a script after name" if tokens.length < 3

      command.name = tokens[1]
      command.content = tokens.slice(2).join ' '

    when 'create'
      return callback new Error "Invalid arguments" if tokens.length != 4

      command.asset = tokens[1]
      return callback new Error "Syntax error, expected 'named'" if tokens[2] != 'named'
      command.name = tokens[3]

    else
      return callback new Error "No such command"

  callback null, command


executeCommand = (command, projectId, callback) ->
  switch command.type
    when 'import'
      backend.importAsset projectId, command.name, command.url, callback

    when 'script'
      backend.addScript projectId, command.name, command.content, callback

    when 'create'
      backend.createObject projectId, command.name, command.asset, callback

  return


logTweetFail = (err) ->
  return if ! err?
  utils.botlog "Could not tweet:\n#{JSON.stringify(err, null, 2)}"

tweetCommandFailed = (username, reason, replyTweetId, callback) ->
  twitter.statuses 'update', { status: "@#{username} ERR #{reason}", in_reply_to_status_id: replyTweetId }, config.twitter.accessToken, config.twitter.accessTokenSecret, (err) ->
    err.tweet = { type: 'failure', reason, replyTweetId } if err?
    callback err

tweetCommandSuccess = (username, projectId, replyTweetId, callback) ->
  twitter.statuses 'update', { status: "@#{username} OK #{baseURL}/p/#{projectId}", in_reply_to_status_id: replyTweetId }, config.twitter.accessToken, config.twitter.accessTokenSecret, (err) ->
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
  # Ignore retweets or tweets mentioning multiple users
  return if data.retweeted_status? or data.entities?.user_mentions?.length != 1
  # Ignore tweets not containing a single project hashtag
  return if data.entities?.hashtags?.length != 1

  # Ensure the tweet isn't trying to mess with us
  return if data.text.split('@').length - 1 > 1 or data.text.split('#').length - 1 > 1

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

  commandText = commandText.trim().replace(/\s{2,}/g, ' ')
  utils.botlog "[#{projectId}] #{data.user.screen_name}: #{commandText}"

  replyTweetId = data.id_str

  parseCommand commandText, (err, command) ->
    return tweetCommandFailed data.user.screen_name, err.message, replyTweetId, logTweetFail if err?

    executeCommand command, projectId, (err) ->
      return tweetCommandFailed data.user.screen_name, err.message, replyTweetId, logTweetFail if err?
      tweetCommandSuccess data.user.screen_name, projectId, replyTweetId, logTweetFail

    return

endCallback = -> utils.botlog "Stream ended, somehow."

twitter.getStream 'userstream', {}, config.twitter.accessToken, config.twitter.accessTokenSecret, dataCallback, endCallback
utils.botlog "Started."
