setupActorAPI = ->
  {
    SetPosition: (self, x, y) ->
      self.transform.x = x
      self.transform.y = y
      return

    GetPosition: (self) ->
      keys: 
        x: self.transform.x
        y: self.transform.y

    Move: (self, dx, dy) ->
      self.transform.x += dx
      self.transform.y += dy
      return

    SetAngle: (self, angle) ->
      self.transform.angle = angle
      return

    GetAngle: (self) ->
      self.transform.angle

    Rotate: (self, dAngle) ->
      self.transform.angle += dAngle
      return
  }

setupInputAPI = (ctx) ->
  activeTouchId = null

  touchPosition = x: 0, y: 0
  newTouchPosition = null
  touchDelta = x: 0, y: 0
  newTouchDelta = x: 0, y: 0
  touchStarted = false
  touchEnded = false

  wasMouseDown = false
  isMouseDown = false
  wasTouchDown = false
  isTouchDown = false

  ctx.canvas.addEventListener 'touchstart', (event) =>
    event.preventDefault()
    return if activeTouchId?

    touch = event.changedTouches[0]
    activeTouchId = touch.identifier

    rect = event.target.getBoundingClientRect()
    newTouchPosition = x: (touch.clientX - rect.left) * window.devicePixelRatio, y: (touch.clientY - rect.top) * window.devicePixelRatio
    newTouchDelta.x = 0
    newTouchDelta.y = 0

    isTouchDown = true
    return

  ctx.canvas.addEventListener 'touchend', (event) =>
    return if activeTouchId != event.changedTouches[0].identifier

    activeTouchId = null
    isTouchDown = false
    return

  ctx.canvas.addEventListener 'touchcancel', (event) =>
    return if activeTouchId != event.changedTouches[0].identifier

    activeTouchId = null
    isTouchDown = false
    return

  ctx.canvas.addEventListener 'touchmove', (event) =>
    event.preventDefault()
    touch = event.changedTouches[0]
    if activeTouchId == touch.identifier
      rect = event.target.getBoundingClientRect()
      newTouchPosition = x: (touch.clientX - rect.left) * window.devicePixelRatio, y: (touch.clientY - rect.top) * window.devicePixelRatio
      newTouchDelta.x = newTouchPosition.x - touchPosition.x
      newTouchDelta.y = newTouchPosition.y - touchPosition.y
    return

  ctx.canvas.addEventListener 'mousedown', (event) =>
    event.preventDefault()
    ctx.canvas.focus()
    
    isMouseDown = true
    newTouchPosition = x: (event.offsetX or event.layerX) - ctx.canvas.width / 2, y: (event.offsetY or event.layerY) - ctx.canvas.height / 2
    
    false
  , false

  document.addEventListener 'mouseup', (event) =>
    event.preventDefault()
    ctx.canvas.focus()
    
    isMouseDown = false
    
    false
  , false

  ctx.canvas.addEventListener 'mousemove', (event) =>
    return unless isMouseDown
    event.preventDefault()
    
    newTouchPosition = x: (event.offsetX or event.layerX) - ctx.canvas.width / 2, y: (event.offsetY or event.layerY) - ctx.canvas.height / 2
    newTouchDelta.x = newTouchPosition.x - touchPosition.x
    newTouchDelta.y = newTouchPosition.y - touchPosition.y
  
    false
  , false



  {
    tick: ->
      touchStarted = (not wasTouchDown and isTouchDown) or (not wasMouseDown and isMouseDown)
      touchEnded = (wasTouchDown and not isTouchDown) or (wasMouseDown and not isMouseDown)
      wasTouchDown = isTouchDown
      wasMouseDown = isMouseDown

      if newTouchPosition?
        touchPosition = newTouchPosition
        newTouchPosition = null
      
      touchDelta = newTouchDelta
      newTouchDelta = x: 0, y: 0
      return

    GetTouchPosition: ->
      keys:
        x: touchPosition.x
        y: touchPosition.y

    GetTouchDelta: ->
      keys:
        x: touchDelta.x
        y: touchDelta.y

    HasTouchStarted: -> touchStarted
    HasTouchEnded: -> touchEnded
  }

window.setupAPI = (ctx) ->
  gdev.api =
    actor: setupActorAPI ctx
    input: setupInputAPI ctx

  # Old API for compatibility with older games
  gdev.api.SetPosition = gdev.api.actor.SetPosition
  gdev.api.GetPosition = gdev.api.actor.GetPosition
  gdev.api.Move = gdev.api.actor.Move
  gdev.api.SetAngle = gdev.api.actor.SetAngle
  gdev.api.GetAngle = gdev.api.actor.GetAngle
  gdev.api.Rotate = gdev.api.actor.Rotate

  return
