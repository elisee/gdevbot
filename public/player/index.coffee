projectPath = "/projects/#{app.project.id.toLowerCase()}"

loadAssets = (callback) ->
  loaderElement = document.getElementById 'Loader'
  progressElement = loaderElement.querySelector 'progress'
  progressElement.max = app.project.assets.length

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

  app.project.assets.forEach (asset) ->
    assetsToLoad.push asset
    
    [ assetName, ext ] = asset.split('.')
    if ext == 'js'
      gdev.behaviors[assetName.toLowerCase()] = {}
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
      sprite: null
      keys: {}

    for componentDef in actorDef.components
      behavior = gdev.behaviors[componentDef.name.toLowerCase()]
      if behavior?
        actor.behaviors.push behavior
      else
        actor.sprite = 
          image: gdev.assetsByName[componentDef.name.toLowerCase()]

    for childActorDef in actorDef.children
      childActor = walkActorDef childActorDef
      childActor.parent = actor
      actor.children.push childActor

    gdev.actorsTree.byName[actor.name.toLowerCase()] = actor
    actor

  for actorDef in app.project.actors
    gdev.actorsTree.roots.push walkActorDef actorDef

  walkActorAwake = (actor) ->
    behavior.Awake actor for behavior in actor.behaviors
    walkActorAwake childActor for childActor in actor.children
    return

  walkActorAwake actor for actor in gdev.actorsTree.roots

  callback()

load = (callback) ->
  setupAPI ctx
  loadAssets -> setupActors -> callback()
  return

walkActorUpdate = (actor) ->
  behavior.Update actor for behavior in actor.behaviors
  walkActorUpdate childActor for childActor in actor.children
  return

walkActorRender = (actor) ->
  ctx.save()
  ctx.translate actor.transform.x, actor.transform.y
  ctx.rotate actor.transform.angle*Math.PI/180

  if actor.sprite?
    ctx.drawImage actor.sprite.image, -actor.sprite.image.width / 2, -actor.sprite.image.height / 2

  walkActorRender childActor for childActor in actor.children

  ctx.restore()
  return

walkActorDebug = (actor) ->
  ctx.save()
  ctx.translate actor.transform.x, actor.transform.y
  ctx.rotate actor.transform.angle*Math.PI/180

  ctx.fillRect -5, -5, 10, 10
  ctx.fillText actor.name, 10, -10

  walkActorDebug childActor for childActor in actor.children

  ctx.restore()
  return

updateInterval = 1 / 60 * 1000
lastTimestamp = 0
accumulatedTime = 0

tick = (timestamp) ->
  gdev.api.input.tick()

  requestAnimationFrame tick
  ctx.canvas.width = ctx.canvas.parentElement.clientWidth
  ctx.canvas.height = ctx.canvas.parentElement.clientHeight

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

  walkActorRender actor for actor in gdev.actorsTree.roots

  if gdev.debug
    ctx.fillStyle = '#f00'
    ctx.font = 'bold 10pt Arial'
    walkActorDebug actor for actor in gdev.actorsTree.roots

  return

window.gdev = vars: {}

canvas = document.querySelector("canvas")
ctx = canvas.getContext("2d")

load tick