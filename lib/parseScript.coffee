# From https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/charCodeAt
fixedCharCodeAt = (str, idx) ->
  idx = idx or 0
  code = str.charCodeAt(idx)
  hi = undefined
  low = undefined
  
  # High surrogate (could change last hex to 0xDB7F to treat high
  # private surrogates as single characters)
  if 0xD800 <= code and code <= 0xDBFF
    hi = code
    low = str.charCodeAt(idx + 1)
    throw "High surrogate not followed by low surrogate in fixedCharCodeAt()"  if isNaN(low)
    return ((hi - 0xD800) * 0x400) + (low - 0xDC00) + 0x10000
  # Low surrogate
  # We return false to allow loops to skip this iteration since should have
  # already handled high surrogate above in the previous iteration
  return false if 0xDC00 <= code and code <= 0xDFFF
  
  #hi = str.charCodeAt(idx-1);
  #        low = code;
  #        return ((hi - 0xD800) * 0x400) + (low - 0xDC00) + 0x10000;
  code

idRegex = /^[A-Za-z0-9_]$/

module.exports = (name, content, callback) ->
  name = name.toLowerCase()

  # Remove line-feeds
  content = content.replace /\r/g, ''
  
  codeBlocks = 
    init: ''
    awake: ''
    update: ''

  activeCodeBlock = 'init'

  # Parse the script
  i = 0
  acc = ''
  tokenStack = []

  makeToken = ->
    return if acc == ''

    val = acc
    acc = ''

    if typeof val == 'number'
      # Emoji
      emojis =
        0x1f305:  type: 'awake',              shortcode: 'sunrise'
        0x27b0:   type: 'update',             shortcode: 'curly_loop'

        0x1f427:  type: 'self',               shortcode: 'penguin'         
        0x1f6c4:  type: 'assign',             shortcode: 'baggage_claim'
        0x1f511:  type: 'key',                shortcode: 'key'
        0x2702:   type: 'scissors',           shortcode: 'scissors'
        0x2704:   type: 'scissors',           shortcode: 'white_scissors'

        0x1f6a9:  type: 'position',           shortcode: 'triangular_flag_on_post'
        0x1f697:  type: 'move',               shortcode: 'car'
        0x2b55:   type: 'angle',              shortcode: 'o'
        0x1f503:  type: 'rotate',             shortcode: 'arrows_clockwise'
        0x1f504:  type: 'rotate',             shortcode: 'arrows_anticlockwise'

        0x2194:   type: 'spriteWidth',        shortcode: 'arrow_left_right'
        0x2195:   type: 'spriteHeight',       shortcode: 'arrow_up_down'

        0x2753:   type: 'if',                 shortcode: 'question'
        0x1f500:  type: 'not',                shortcode: 'twisted_rightwards_arrows'
        0x23e9:   type: 'blockStart',         shortcode: 'fast_forward'
        0x23ea:   type: 'blockEnd',           shortcode: 'rewind'

        0x270b:   type: 'touchPosition',      shortcode: 'hand'
        0x1f44b:  type: 'touchDelta',         shortcode: 'wave'
        0x1f446:  type: 'touchStart',         shortcode: 'point_up_2'
        0x261d:   type: 'touchEnd',           shortcode: 'point_up'

        0x1f3b2:  type: 'random',             shortcode: 'random'

      emoji = emojis[val] or { type: 'unknown' }
      console.log "Unknown emoji: 0x#{val.toString(16)}" if emoji.type == 'unknown'
      tokenStack.push emoji
      return

    return tokenStack.push { type: 'number', value: +val } if ! isNaN(val)

    switch val
      when '≤', '<=' then tokenStack.push { type: '<=' }
      when '≥', '>=' then tokenStack.push { type: '>=' }
      when '=' then tokenStack.push { type: '==' }
      when '≠' then tokenStack.push { type: '!=' }
      when '<', '>', '+', '-', '*', '/', '%'
        tokenStack.push { type: val }
      else
        tokenStack.push { type: 'id', value: val }
    return

  generateCode = ->
    consumeStatement() while tokenStack.length > 0

  consumeStatement = ->
    token = tokenStack.splice(0, 1)[0]

    console.log "[stat] #{token.type}"

    switch token.type
      when 'awake', 'update'
        activeCodeBlock = token.type

      when 'position'
        codeBlocks[activeCodeBlock] += "gdev.api.actor.SetPosition(#{consumeExpression()}, #{consumeExpression()}, #{consumeExpression()});"
      when 'move'
        codeBlocks[activeCodeBlock] += "gdev.api.actor.Move(#{consumeExpression()}, #{consumeExpression()}, #{consumeExpression()});"
      when 'angle'
        codeBlocks[activeCodeBlock] += "gdev.api.actor.SetAngle(#{consumeExpression()}, #{consumeExpression()});"
      when 'rotate'
        codeBlocks[activeCodeBlock] += "gdev.api.actor.Rotate(#{consumeExpression()}, #{consumeExpression()});"

      when 'if'
        codeBlocks[activeCodeBlock] += "if(#{consumeExpression()})"
      when 'blockStart'
        codeBlocks[activeCodeBlock] += "{"
      when 'blockEnd'
        codeBlocks[activeCodeBlock] += "}"
      when 'statementEnd'
        break

      when 'assign'
        codeBlocks[activeCodeBlock] += "#{consumeExpression()}=#{consumeExpression()};"

      else
        # TODO: callback with an error
        console.log "Not a statement: #{JSON.stringify token, null, 2}"

    codeBlocks[activeCodeBlock] += '\n'
    return

  consumeExpression = ->
    return null if tokenStack.length == 0

    code = null
    token = tokenStack.splice(0, 1)[0]

    console.log "[expr] #{token.type}"

    switch token.type
      when 'number'
        code = token.value.toString()
      when '-'
        code = "-#{consumeExpression()}"
      when 'self'
        code = 'self'
      when 'id'
        code = "gdev.vars.#{token.value}"
      when 'scissors'
        return 'null'
      when 'not'
        code = "!(#{consumeExpression()})"

      when 'position'
        code = "gdev.api.actor.GetPosition(#{consumeExpression()})"
      when 'angle'
        code = "gdev.api.actor.GetAngle(#{consumeExpression()})"

      when 'spriteWidth'
        code = "gdev.api.actor.GetSpriteWidth(#{consumeExpression()})"
      when 'spriteHeight'
        code = "gdev.api.actor.GetSpriteHeight(#{consumeExpression()})"

      when 'touchPosition'
        code = "gdev.api.input.GetTouchPosition()"
      when 'touchDelta'
        code = "gdev.api.input.GetTouchDelta()"
      when 'touchStart'
        code = "gdev.api.input.HasTouchStarted()"
      when 'touchEnd'
        code = "gdev.api.input.HasTouchEnded()"

      when 'random'
        code = "gdev.api.math.Random(#{consumeExpression()},#{consumeExpression()})"
      else
        # Not an expression? Backtrack
        tokenStack.unshift token
        console.log "[back]"
        return null

    followUp = consumeExpressionFollowUp()
    return if followUp? then "#{code}#{followUp}" else code

  consumeExpressionFollowUp = ->
    return null if tokenStack.length == 0

    code = null
    token = tokenStack.splice(0, 1)[0]

    console.log "[fllw] #{token.type}"

    switch token.type
      when '+', '-', '*', '/', '%', '<', '>', '<=', '>=', '==', '!='
        secondOperand = consumeExpression()
        return "#{token.type}#{secondOperand}"

      when 'scissors'
        return null

      when 'key'
        code = ".keys[#{consumeIndex()}]"
      else
        # Not an expression follow-up? Backtrack
        tokenStack.unshift token
        console.log "[back]"
        return null

    followUp = consumeExpressionFollowUp()
    return if followUp? then "#{code}#{followUp}" else code

  consumeIndex = ->
    return null if tokenStack.length == 0

    token = tokenStack.splice(0, 1)[0]

    switch token.type
      when 'id'
        return "\"#{token.value}\""
      when 'number'
        return token.value.toString()
      else
        # Not an indexable? Put the token back in its place
        tokenStack.unshift token

    return null

  while i < content.length
    charCode = fixedCharCodeAt content, i
    if charCode == false
      # Ignore
    else if charCode >= 128
      makeToken()
      acc = charCode
      makeToken()
    else
      char = content[i]

      if char == ' ' or char == '\n'
        makeToken()
        tokenStack.push { type: 'statementEnd' } if char == '\n'
      else
        # Check for operator that should be tokenized
        if acc in [ '≤', '<=', '≥', '>=', '=', '≠', '<', '>', '+', '-', '*', '/', '%' ]
          makeToken()
        # Check for alphanumeric boundary
        else if acc.length > 0 and ((idRegex.test(acc[acc.length-1]) and !idRegex.test(char)) or (!idRegex.test(acc[acc.length-1]) and idRegex.test(char)))
          makeToken()
        acc += char

    i++

  makeToken()
  tokenStack.push { type: 'statementEnd' } if char == '\n'
  generateCode()

  # Finish up the script
  codeBlocks.awake = "behavior_#{name}.Awake = function(self) {\n#{codeBlocks.awake}\n}"
  codeBlocks.update = "behavior_#{name}.Update = function(self) {\n#{codeBlocks.update}\n}"

  script = "var behavior_#{name} = gdev.behaviors.#{name};" 
  script = [ '(function(){', script, codeBlocks.init, codeBlocks.awake, codeBlocks.update, '})();' ].join '\n'

  callback null, script
