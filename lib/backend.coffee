utils = require './utils'
parseScript = require './parseScript'
mkdirp = require 'mkdirp'
path = require 'path'
request = require 'request'
gm = require 'gm'
fs = require 'fs'

try mkdirp.sync path.join __dirname, '..', 'public', 'data'

module.exports = backend =

  nameRegex: /^[A-Za-z0-9_]{3,40}$/

  createProject: (projectId, callback) ->
    return callback new Error "Invalid project name" if ! backend.nameRegex.test projectId

    fs.exists path.join(__dirname, '..', 'public', 'data', projectId.toLowerCase()), (exists) ->
      return callback new Error 'Project name already taken' if exists

      mkdirp path.join(__dirname, '..', 'public', 'data', projectId.toLowerCase(), 'assets'), (err) ->
        return callback new Error 'Unexpected error' if err?
        callback null

  importAsset: (projectId, name, url, callback) ->
    return callback new Error "Invalid asset name" if ! backend.nameRegex.test name

    mkdirp path.join(__dirname, '..', 'public', 'data', projectId.toLowerCase(), 'assets'), (err) ->
      return callback new Error 'Unexpected error' if err? and err.code != 'EEXIST'

      # TODO: Abort request if size is too big
      request { url, encoding: null }, (err, response, body) ->
        return callback new Error 'Failed to download asset' if err? or response.statusCode != 200

        # TODO: Implement support for other asset types
        gm(body).resize(1024,1024).write path.join(__dirname, '..', 'public', 'data', projectId.toLowerCase(), 'assets', "#{name}.png"), (err) ->
          if err?
            utils.botlog JSON.stringify err, null, 2
            callback new Error 'Failed to import asset'
            return

          callback null

      return

  addScript: (projectId, name, content, callback) ->
    return callback new Error "Invalid script name" if ! backend.nameRegex.test name

    parseScript name, content, (err, script) ->
      if err?
        utils.botlog JSON.stringify err, null, 2
        callback new Error 'Failed to parse script'
        return

      assetsPath = path.join(__dirname, '..', 'public', 'data', projectId.toLowerCase(), 'assets')
      mkdirp assetsPath, (err) ->
        return callback new Error 'Unexpected error' if err? and err.code != 'EEXIST'

        fs.writeFile path.join(assetsPath, name + ".js"), script, (err) ->
          if err?
            utils.botlog JSON.stringify err, null, 2
            callback new Error 'Failed to save script'
            return

          callback null

  createActor: (projectId, name, assetName, callback) ->
    return callback new Error "Invalid actor name" if ! backend.nameRegex.test name
    return callback new Error "Invalid asset name" if ! backend.nameRegex.test assetName

    # TODO: Implement creating an actor
    callback null
