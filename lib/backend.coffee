utils = require './utils'
parseScript = require './parseScript'

async = require 'async'
mkdirp = require 'mkdirp'
path = require 'path'
request = require 'request'
gm = require 'gm'
fs = require 'fs'
sqlite3 = require 'sqlite3'

db = new sqlite3.Database path.join __dirname, '..', 'projectLogs.sq3db'
db.run 'CREATE TABLE IF NOT EXISTS projectLogs (id INTEGER PRIMARY KEY, projectId TEXT, tweetId TEXT, tweetText TEXT, tweetHTML TEXT, success BOOLEAN, response TEXT)', (err) ->
  if err?
    console.log 'Error while creating projectLogs table:'
    console.log err

nameRegex = /^[A-Za-z0-9_]{1,40}$/

makeProject = (projectId) ->
  projectsById[projectId.toLowerCase()] = project =
    id: projectId
    metadata: { published: false, members: { list: [], byId: {} } }
    assetsByName: []
    actorsTree: { roots: [], byName: {}, parentsByChildName: {} }

  project

writeMetadata = (project, callback) ->
  metadata = { published: project.metadata.published, members: project.metadata.members.list }

  fs.writeFile path.join(projectsPath, project.id.toLowerCase(), 'metadata.json'), JSON.stringify(metadata, null, 2), (err) ->
    if err?
      utils.botlog "[#{project.id}] Error saving metadata.json:"
      utils.botlog JSON.stringify err, null, 2
      callback new Error 'Could not save metadata to disk'

    callback null


writeActors = (project, callback) ->
  fs.writeFile path.join(projectsPath, project.id.toLowerCase(), 'actors.json'), JSON.stringify(project.actorsTree.roots, null, 2), (err) ->
    if err?
      utils.botlog "[#{project.id}] Error saving actors.json:"
      utils.botlog JSON.stringify err, null, 2
      callback new Error 'Could not save actors to disk'

    callback null


# Load projects
projectsPath = path.join __dirname, '..', 'public', 'projects'
try mkdirp.sync projectsPath
projectsById = {}
publishedGames = []

for projectEntry in fs.readdirSync path.join projectsPath
  project = makeProject projectEntry

  # Metadata
  metadataJSON = null
  try metadataJSON = fs.readFileSync path.join projectsPath, projectEntry, 'metadata.json'
  if metadataJSON?
    metadata = JSON.parse metadataJSON

    project.metadata.members.list = metadata.members
    for member in project.metadata.members.list
      project.metadata.members.byId[ member.id ] = member

    project.metadata.published = metadata.published
    publishedGames.push project if project.metadata.published
  
  if project.metadata.members.list.length == 0
    # We need at least one member for each project
    # If metadata couldn't be loaded,
    # fallback to making the bot itself the creator
    config = require '../config'
    dummyCreator = id: config.twitter.userId, cachedUsername: config.twitter.username
    project.metadata.members.list.push dummyCreator
    project.metadata.members.byId[dummyCreator.id] = dummyCreator

  # Asset entries
  try assetEntries = fs.readdirSync path.join projectsPath, projectEntry, 'assets'
  if assetEntries?
    for assetEntry in assetEntries
      [ assetName, ext ] = assetEntry.split '.'

      asset = name: assetName

      switch ext
        when 'js' then asset.type = 'script'
        else asset.type = 'image'

      project.assetsByName[asset.name.toLowerCase()] = asset

  # Actors
  try actorsJSON = fs.readFileSync path.join(projectsPath, projectEntry, 'actors.json'), encoding: 'utf8'
  if actorsJSON?
    project.actorsTree.roots = JSON.parse actorsJSON

    walkActor = (actor, parent) ->
      project.actorsTree.parentsByChildName[actor.name.toLowerCase()] = parent
      project.actorsTree.byName[actor.name.toLowerCase()] = actor
      walkActor child, actor for child in actor.children
      return

    walkActor actor, null for actor in project.actorsTree.roots


module.exports = backend =

  publishedGames: publishedGames

  logTweet: (projectId, tweet, success, response, callback) ->
    request { url: "https://api.twitter.com/1/statuses/oembed.json?id=#{tweet.id_str}&hide_media=true&hide_thread=true&omit_script=true" }, (err, reqResponse, body) ->
      if err?
        console.log "Failed to fetch tweet #{tweet.id_str}:"
        console.log err
        tweetHTML = '<blockquote class="twitter-tweet"><p>Failed to fetch Tweet</p><a href="https://twitter.com/statuses/' + tweet.id_str + '">Link</a></blockquote>'
      else
        tweetHTML = JSON.parse(body).html

      logEntry =
        projectId: projectId.toLowerCase()
        tweetId: tweet.id_str
        tweetText: tweet.text
        tweetHTML: tweetHTML
        success: success
        response: response

      db.run 'INSERT INTO projectLogs (projectId, tweetId, tweetText, tweetHTML, success, response) VALUES(?,?,?,?,?,?)', [ logEntry.projectId, logEntry.tweetId, logEntry.tweetText, logEntry.tweetHTML, logEntry.success, logEntry.response ], (err) ->
        if err?
          console.log "Error while inserting tweet #{tweet.id_str} into project log:"
          console.log err
          return callback err

        return callback null, logEntry

  getProjectLog: (projectId, maxTweets, callback) ->
    db.all 'SELECT * FROM projectLogs WHERE projectId=? ORDER BY id DESC LIMIT ?', [ projectId.toLowerCase(), maxTweets ], callback

  createProject: (projectId, user, callback) ->
    return process.nextTick ( -> callback new Error "Invalid project name" ) if ! nameRegex.test projectId
    return process.nextTick ( -> callback new Error "Project name is already used" ) if projectsById[projectId]?

    fs.mkdir path.join(projectsPath, projectId.toLowerCase()), (err) ->
      if err?
        return callback new Error 'Project name is already used'  if err.code == 'EEXIST'
        utils.botlog "[#{projectId}] Unexpected error creating project folder:"
        utils.botlog JSON.stringify err, null, 2
        return callback new Error "Unexpected error"

      project = makeProject projectId

      creator =
        # Can link to account with twitter.com/account/redirect_by_id/#{id}
        id: user.id_str
        # Storing the username just for display purpose
        # the actual membership is based on the immutable account ID
        cachedUsername: user.screen_name

      project.metadata.members.list.push creator
      project.metadata.members.byId[creator.id] = creator

      mkdirp path.join(projectsPath, projectId.toLowerCase(), 'assets'), (err) ->
        if err? and err.code != 'EEXIST'
          utils.botlog "[#{projectId}] Unexpected error creating assets folder:"
          utils.botlog JSON.stringify err, null, 2
          return callback new Error 'Unexpected error' if err? 

        async.series [
          (callback) -> writeMetadata project, callback
          (callback) -> writeActors project, callback
        ], callback

  getProject: (projectId, user, role, callback) ->
    project = projectsById[projectId.toLowerCase()]
    return process.nextTick ( -> callback new Error "No such project" ) if ! project?

    member = project.metadata.members.byId[user.id_str]
    return process.nextTick ( -> callback new Error "You're not a member, ask @#{project.metadata.members.list[0].cachedUsername} for access" ) if ! member?

    if role == 'admin' and project.metadata.members.list.indexOf(member) != 0
      return process.nextTick ( -> callback new Error "You're not the project admin" )

    if member.cachedUsername != user.screen_name
      writeMetadata project, (err) ->
        if err?
          # Just logging any saving error here, it's not a deal breaker.
          utils.botlog "[#{projectId}] Unexpected error saving project metadata:"
          utils.botlog JSON.stringify err, null, 2

        callback null, project
      return

    callback null, project
    return

  setCover: (project, url, callback) ->
    # TODO: Abort request if size is too big
    request { url, encoding: null }, (err, response, body) ->
      return callback new Error 'Failed to download cover' if err? or response.statusCode != 200

      gm(body).resize(1280,800,'>').write path.join(projectsPath, project.id.toLowerCase(), "cover.png"), (err) ->
        if err?
          utils.botlog "[#{project.id}] Error importing cover from #{url}:"
          utils.botlog JSON.stringify err, null, 2
          return callback new Error 'Failed to process cover'

        callback null

      return

  publish: (project, callback) ->
    fs.exists path.join(projectsPath, project.id.toLowerCase(), "cover.png"), (exists) ->
      return callback new Error 'A cover is required to publish' if ! exists
      return callback new Error 'Project is already published' if project.metadata.published

      project.metadata.published = true
      publishedGames.push project
      writeMetadata project, callback

  unpublish: (project, callback) ->
    return callback new Error 'Project is not published' if  project.metadata.published

    project.metadata.published = false
    publishedGames.splice publishedGames.indexOf(project), 1
    writeMetadata project, callback

  addMembers: (project, members, callback) ->
    for member in members
      continue if project.metadata.members.byId[member.id]?
      project.metadata.members.list.push member
      project.metadata.members.byId[member.id] = member

    writeMetadata project, callback

  removeMembers: (project, memberIds, callback) ->
    for memberId in memberIds
      member = project.metadata.members.byId[memberId]
      continue if ! member?

      memberIndex = project.metadata.members.list.indexOf(member)
      # Prevent removing the project creator
      continue if memberIndex == 0

      project.metadata.members.list.splice memberIndex, 1
      delete project.metadata.members.byId[memberId]

    writeMetadata project, callback

  importAsset: (project, name, url, callback) ->
    return process.nextTick ( -> callback new Error "Invalid asset name" ) if ! nameRegex.test name

    # TODO: Abort request if size is too big
    request { url, encoding: null }, (err, response, body) ->
      return callback new Error 'Failed to download asset' if err? or response.statusCode != 200

      # TODO: Allow importing sounds (and even 3D models maybe?)
      assetType = 'image'

      existingAsset = project.assetsByName[name.toLowerCase()]
      if existingAsset? and existingAsset.type != assetType
        return callback new Error "Name already used by an asset of type \"#{existingAsset.type}\""

      # TODO: Implement support for other asset types
      gm(body).resize(2048,2048,'>').write path.join(projectsPath, project.id.toLowerCase(), 'assets', "#{name}.png"), (err) ->
        if err?
          utils.botlog "[#{project.id}] Error processing import of #{url}:"
          utils.botlog JSON.stringify err, null, 2
          return callback new Error 'Failed to import asset'

        project.assetsByName[name.toLowerCase()] = { name: name, type: assetType }
        callback null

      return

  addScript: (project, name, content, callback) ->
    return process.nextTick ( -> callback new Error "Invalid script name" ) if ! nameRegex.test name

    existingAsset = project.assetsByName[name.toLowerCase()]
    if existingAsset? and existingAsset.type != 'script'
      return process.nextTick ( -> callback new Error "Name already used by an asset of type \"#{existingAsset.type}\"" ) 

    parseScript name, content, (err, script) ->
      if err?
        utils.botlog "[#{project.id}] Error parsing script #{name}:"
        utils.botlog JSON.stringify err, null, 2
        callback new Error 'Failed to parse script'
        return

      assetsPath = path.join(projectsPath, project.id.toLowerCase(), 'assets')
      fs.writeFile path.join(assetsPath, "#{name}.js"), script, (err) ->
        if err?
          utils.botlog "[#{project.id}] Error saving script #{name}:"
          utils.botlog JSON.stringify err, null, 2
          callback new Error 'Failed to save script'
          return

        project.assetsByName[name.toLowerCase()] = { name: name, type: 'script' }
        callback null

  createActor: (project, name, parentName, callback) ->
    return process.nextTick ( -> callback new Error "Invalid actor name" ) if name == 'root' or ! nameRegex.test name
    return process.nextTick ( -> callback new Error "Actor name is already used" ) if project.actorsTree.byName[name.toLowerCase()]?

    actor = { name, children: [], components: [] }

    if parentName? and parentName != 'root'
      return process.nextTick ( -> callback new Error "Invalid parent name" ) if ! nameRegex.test parentName

      parentActor = project.actorsTree.byName[parentName.toLowerCase()]
      return process.nextTick ( -> callback new Error "No such parent actor" ) if ! parentActor?

      parentActor.children.push actor
      project.actorsTree.parentsByChildName[actor.name.toLowerCase()] = parentActor
    else
      project.actorsTree.roots.push actor
      project.actorsTree.parentsByChildName[actor.name.toLowerCase()] = null

    project.actorsTree.byName[actor.name.toLowerCase()] = actor
    writeActors project, callback

  reparentActor: (project, name, parentName, callback) ->
    return process.nextTick ( -> callback new Error "Invalid actor name" ) if ! nameRegex.test name

    actor = project.actorsTree.byName[name.toLowerCase()]
    return process.nextTick ( -> callback new Error "No such actor" ) if ! actor?

    # Remove from old parent
    oldParent = project.actorsTree.parentsByChildName[actor.name.toLowerCase()]
    if oldParent?
      oldParent.children.splice oldParent.children.indexOf(actor), 1
    else
      project.actorsTree.roots.splice project.actorsTree.roots.indexOf(actor), 1

    # Add to new parent
    if parentName? and parentName != 'root'
      return process.nextTick ( -> callback new Error "Invalid parent name" ) if ! nameRegex.test parentName

      parentActor = project.actorsTree.byName[parentName.toLowerCase()]
      return process.nextTick ( -> callback new Error "No such parent actor" ) if ! parentActor?

      ancestorActor = parentActor
      while ancestorActor?
        ancestorActor = project.actorsTree.parentsByChildName[ancestorActor.name.toLowerCase()]
        return process.nextTick ( -> callback new Error "Cannot reparent an actor to one of its descendant" ) if ancestorActor == actor

      parentActor.children.push actor
      project.actorsTree.parentsByChildName[actor.name.toLowerCase()] = parentActor
    else
      project.actorsTree.roots.push actor
      project.actorsTree.parentsByChildName[actor.name.toLowerCase()] = null

    writeActors project, callback

  addComponent: (project, actorName, assetName, callback) ->
    return process.nextTick ( -> callback new Error "Invalid actor name" ) if ! nameRegex.test actorName
    return process.nextTick ( -> callback new Error "Invalid asset name" ) if ! nameRegex.test assetName

    actor = project.actorsTree.byName[actorName.toLowerCase()]
    return process.nextTick ( -> callback new Error "No such actor" ) if ! actor?

    asset = project.assetsByName[assetName.toLowerCase()]
    return process.nextTick ( -> callback new Error "No such asset" ) if ! asset?

    componentsOfType = 0

    for component in actor.components
      if component.name.toLowerCase() == assetName.toLowerCase()
        return process.nextTick ( -> callback new Error "Component already exists" )
      if project.assetsByName[component.name.toLowerCase()]?.type == asset.type
        componentsOfType++

    if asset.type == 'image' and componentsOfType > 0
      return process.nextTick ( -> callback new Error "This actor already has an image" )

    actor.components.push name: assetName
    writeActors project, callback

  removeComponent: (project, actorName, assetName, callback) ->
    return process.nextTick ( -> callback new Error "Invalid asset name" ) if ! nameRegex.test assetName
    return process.nextTick ( -> callback new Error "Invalid actor name" ) if ! nameRegex.test actorName

    actor = project.actorsTree.byName[actorName.toLowerCase()]
    return process.nextTick ( -> callback new Error "No such actor" ) if ! actor?

    for component, i in actor.components
      if component.name.toLowerCase() == assetName.toLowerCase()
        actor.components.splice i, 1
        return writeActors project, callback

    return process.nextTick -> callback new Error "No such asset"

