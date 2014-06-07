projectPath = "/projects/#{app.projectId.toLowerCase()}"

loadAssets = (callback) ->
  loaderElement = document.getElementById 'Loader'
  progressElement = loaderElement.querySelector 'progress'
  progressElement.max = app.assets.length

  assetsToLoad = []
  onAssetLoaded = (name, asset) ->
    console.log "Loaded #{name}"

    gdev.assetsByName[name.toLowerCase()] = asset if asset?

    assetsToLoad.splice assetsToLoad.indexOf(asset), 1
    progressElement.value++

    if assetsToLoad.length == 0
      loaderElement.parentElement.removeChild loaderElement
      callback()
    return

  gdev.behaviors = {}
  gdev.assetsByName = {}

  app.assets.forEach (asset) ->
    assetsToLoad.push asset
    
    [ assetName, ext ] = asset.split('.')
    if ext == 'js'
      script = document.createElement 'script'
      script.onload = -> onAssetLoaded assetName
      script.src = "#{projectPath}/assets/#{asset}"
      document.head.appendChild script
    else
      img = new Image()
      img.onload = -> onAssetLoaded assetName, img
      img.src = "#{projectPath}/assets/#{asset}"

  return

setupActors = (callback) ->
  gdev.actorsTree =
    roots: []
    byName: {}

  walkActorDef = (actorDef) ->
    actor =
      name: actorDef.name
      children: []
      transform: { x: 0, y: 0, angle: 0 }
      behaviors: []
      sprites: []

    for componentDef in actorDef.components
      behavior = gdev.behaviors[componentDef.name]
      if behavior?
        actor.behaviors.push behavior
      else
        # FIXME: renderers rather than sprites?
        actor.sprites.push
          image: gdev.assetsByName[componentDef.name.toLowerCase()]

    for childActorDef in actorDef.children
      childActor = walkActorDef childActorDef
      childActor.parent = actor
      actor.children.push childActor

    gdev.actorsTree.byName[actor.name.toLowerCase()] = actor
    actor

  for actorDef in app.actors
    gdev.actorsTree.roots.push walkActorDef actorDef

  walkActorAwake = (actor) ->
    behavior.Awake actor for behavior in actor.behaviors
    walkActorAwake childActor for childActor in actor.children
    return

  walkActorAwake actor for actor in gdev.actorsTree.roots

  callback()

load = (callback) ->
  setupAPI()

  loadAssets -> setupActors -> callback()
  return

setupAPI = ->
  gdev.api = {}

  gdev.api.SetPosition = (self, x, y) ->
    self.transform.x = x
    self.transform.y = y
    return

  gdev.api.Move = (self, dx, dy) ->
    self.transform.x += dx
    self.transform.y += dy
    return

  gdev.api.SetAngle = (self, angle) ->
    self.transform.angle = angle
    return

  gdev.api.Rotate = (self, dAngle) ->
    self.transform.angle += dAngle
    return

walkActorUpdate = (actor) ->
  behavior.Update actor for behavior in actor.behaviors
  walkActorUpdate childActor for childActor in actor.children
  return

updateInterval = 1 / 60 * 1000
lastTimestamp = 0
accumulatedTime = 0

tick = (timestamp) ->
  requestAnimationFrame tick
  ctx.canvas.width = window.innerWidth
  ctx.canvas.height = window.innerHeight

  # Logic
  timestamp = timestamp || 0
  accumulatedTime += timestamp - lastTimestamp
  lastTimestamp = timestamp

  if accumulatedTime > 5 * updateInterval
    # Game is running slowly, don't fall into the well of dispair
    accumulatedTime = updateInterval * 5
  
  while accumulatedTime >= updateInterval
    walkActorUpdate actor for actor in gdev.actorsTree.roots
    accumulatedTime -= updateInterval

  # Render
  ctx.fillStyle = '#000'
  ctx.fillRect 0, 0, ctx.canvas.width, ctx.canvas.height
  ctx.translate ctx.canvas.width / 2, ctx.canvas.height / 2

  ctx.fillStyle = '#f00'
  for actor in gdev.actorsTree.roots
    for sprite in actor.sprites
      ctx.save()
      ctx.translate actor.transform.x, actor.transform.y
      ctx.rotate actor.transform.angle*Math.PI/180
      ctx.drawImage sprite.image, -sprite.image.width / 2, -sprite.image.height / 2
      ctx.restore()
    ctx.fillRect actor.transform.x - 5, actor.transform.y - 5, 10, 10

  return


window.gdev = {}
canvas = document.querySelector("canvas")
ctx = canvas.getContext("2d")

load tick