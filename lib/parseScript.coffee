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

module.exports = (name, content, callback) ->
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
      console.log 'emoji!'
      # Emoji
      emojis =
        0x1f305:  type: 'awake',              name: 'sunrise'
        0x27b0:   type: 'update',             name: 'curly loop'

        0x1f427:  type: 'self',               name: 'penguin'         
        0x1f517:  type: 'link',               name: 'link'

        0x1f6a9:  type: 'position',           name: 'flag with pole'
        0x1f697:  type: 'move',               name: 'automobile'

        0x2b55:   type: 'angle',              name: 'heavy large circle'
        0x1f504:  type: 'rotate',             name: 'anticlockwise downwards and upwards open circle arrows'

        0x261d:   type: 'touchPosition',      name: 'white up-pointing backhand index'
        0x270b:   type: 'touchDelta',         name: 'waving hand sign'

        0x2194:   type: 'horizontal',         name: 'left-right arrow'
        0x2195:   type: 'vertical',           name: 'up-down arrow'

        0x2753:   type: 'if',                 name: 'black question mark ornament'
        0x23e9:   type: 'startBlock',         name: 'black right-pointing double triangle'
        0x23ea:   type: 'endBlock',           name: 'black right-pointing double triangle'

      emoji = emojis[val] or { type: 'unknown' }
      tokenStack.push emoji
      return

    return tokenStack.push { type: 'number', value: +val } if ! isNaN(val)

    switch val
      when '≤', '<=' then tokenStack.push { type: '<=' }
      when '≥', '>=' then tokenStack.push { type: '>=' }
      when '=' then tokenStack.push { type: '==' }
      when '<', '>', '+', '-', '*', '/', '%'
        tokenStack.push { type: val }
      else
        tokenStack.push { type: 'id', value: val }
    return

  generateCode = ->
    consumeStatement() while tokenStack.length > 0

  consumeStatement = ->
    token = tokenStack.splice(0, 1)[0]

    switch token.type
      when 'awake', 'update'
        console.log 'heh'
        activeCodeBlock = token.type
        console.log activeCodeBlock

      when 'position'
        codeBlocks[activeCodeBlock] += "gdev.api.SetPosition(#{consumeExpression()}, #{consumeExpression()}, #{consumeExpression()});"
      when 'move'
        codeBlocks[activeCodeBlock] += "gdev.api.Move(#{consumeExpression()}, #{consumeExpression()}, #{consumeExpression()});"
      when 'angle'
        codeBlocks[activeCodeBlock] += "gdev.api.SetAngle(#{consumeExpression()}, #{consumeExpression()});"
      when 'rotate'
        codeBlocks[activeCodeBlock] += "gdev.api.Rotate(#{consumeExpression()}, #{consumeExpression()});"

      when 'if'
        codeBlocks[activeCodeBlock] += "if(#{consumeExpression()})"
      when 'startBlock'
        codeBlocks[activeCodeBlock] += "{"
      when 'endBlock'
        codeBlocks[activeCodeBlock] += "}"
      when 'endStatement'
        break

      else
        # TODO: callback with an error
        console.log "Unexpected token type: #{JSON.stringify token, null, 2}"

    codeBlocks[activeCodeBlock] += '\n'
    return

  consumeExpression = ->
    return null if tokenStack.length == 0

    code = null
    token = tokenStack.splice(0, 1)[0]

    switch token.type
      when 'number'
        code = token.value.toString()
      when 'self'
        code = 'self'
      when 'id'
        code = "gdevAPI.vars.#{id.val}" 
      else
        # Not an expression? Put the token back in its place and return
        tokenStack.unshift token
        return null

    followUp = consumeExpressionFollowUp()
    return if followUp? then "#{code}#{followUp}" else code

  consumeExpressionFollowUp = ->
    return null if tokenStack.length == 0

    code = null
    token = tokenStack.splice(0, 1)[0]

    switch token.type
      when '+', '-', '*', '/', '%', '<', '>', '<=', '>=', '=='
        secondOperand = consumeExpression()
        return "#{token.type}#{secondOperand}"

      when 'link' then code = '.'
      when 'id' then code = "#{id.val}"
      else
        # Not an expression? Put the token back in its place and return
        tokenStack.unshift token
        return null

    followUp = consumeExpressionFollowUp()
    return if followUp? then "#{code}#{followUp}" else code

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
        acc += char

    i++

  makeToken()
  tokenStack.push { type: 'statementEnd' } if char == '\n'
  generateCode()

  # Finish up the script
  codeBlocks.awake = "behavior_#{name}.Awake = function(self) {\n#{codeBlocks.awake}\n}"
  codeBlocks.update = "behavior_#{name}.Update = function(self) {\n#{codeBlocks.update}\n}"

  script = "var behavior_#{name} = gdev.behaviors.#{name} = {};" 
  script = [ '(function(){', script, codeBlocks.init, codeBlocks.awake, codeBlocks.update, '})();' ].join '\n'

  callback null, script
