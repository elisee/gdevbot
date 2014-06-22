buttonsElt = document.querySelector('.PlaygroundFlex .Buttons')
scriptEditorElt = document.querySelector('.ScriptEditor')
generatedScriptPreviewElt = document.querySelector('.GeneratedScriptPreview')

projectNameElt = document.querySelector('.ScriptEditorContainer .ProjectName')
scriptNameElt = document.querySelector('.ScriptEditorContainer .ScriptName')

updateTitle = (event) -> document.title = "#{scriptNameElt.textContent or "name"} ##{projectNameElt.textContent or "Project"}"

projectNameElt.addEventListener 'input', updateTitle
scriptNameElt.addEventListener 'input', updateTitle

emojiHTMLbyShortcodes = {}
for group in buttonsElt.children
  for buttonElt in group.children
    target = buttonElt
    wrap = document.createElement 'div'
    wrap.appendChild target.cloneNode true
    emojiHTMLbyShortcodes[buttonElt.dataset.shortcode] = wrap.innerHTML

examples =
  setPositionOnSunrise: ":sunrise: :triangular_flag_on_post: :penguin: 20 30"
  moveRightwards: ":curly_loop: :car: :penguin: 5 0"
  moveUpThenStop: ":curly_loop: :question: :triangular_flag_on_post: :penguin: :scissors: :key: y < 100 \n:car: :penguin: 0 5"
  dragHorizontally: ":curly_loop: :car: :penguin: :wave: :key: x 0"


onClickEmojiButton = (event) ->
  return if event.target.tagName != 'IMG'
  return if ! event.target.dataset.shortcode?

  text = scriptEditorElt.value
  emojiText = event.target.dataset.shortcode

  selection = window.getSelection()
  
  img = document.createElement('img')
  img.src = event.target.src
  img.alt = event.target.dataset.shortcode

  done = false

  if selection.rangeCount > 0
    range = selection.getRangeAt(0)

    isInside = range.startContainer == scriptEditorElt and range.endContainer == scriptEditorElt

    if ! isInside
      parent = range.commonAncestorContainer
      while parent? and parent != scriptEditorElt
        parent = parent.parentElement

      isInside = parent == scriptEditorElt

    if isInside
      range.deleteContents()
      range.insertNode img

      selection.removeAllRanges()
      selection.addRange range
      done = true

  if ! done
    scriptEditorElt.appendChild img

  range.setStartAfter img
  selection.removeAllRanges()
  selection.addRange range

  updateScriptPreview()
  scriptEditorElt.focus()
  return

makeScript = (src, html, br) ->
  code = src
  code = code.trim().replace /\s{2,}/g, ' '
  code = code.replace /: :/g, '::'
  code = code.replace /\n/g, '<br>' if br

  for group in buttonsElt.children
    for buttonElt in group.children
      code = code.replace new RegExp(buttonElt.dataset.shortcode, 'g'), if html then emojiHTMLbyShortcodes[buttonElt.dataset.shortcode] else buttonElt.getAttribute 'alt'

  code
  
# Taken from http://www.456bereastreet.com/archive/201105/get_element_text_including_alt_text_for_images_with_javascript/
getElementText = (el) ->
  text = ""
  
  # Text node (3) or CDATA node (4) - return its text
  if (el.nodeType is 3) or (el.nodeType is 4)
    text = el.nodeValue
  
  # If node is an element (1) and an img, input[type=image], or area element, return its alt text
  else if (el.nodeType is 1) and ((el.tagName.toLowerCase() is "img") or (el.tagName.toLowerCase() is "area") or ((el.tagName.toLowerCase() is "input") and el.getAttribute("type") and (el.getAttribute("type").toLowerCase() is "image")))
    text = el.getAttribute("alt") or ""
  
  # Traverse children unless this is a script or style element
  else if (el.nodeType is 1) and not el.tagName.match(/^(script|style)$/i)
    children = el.childNodes
    i = 0
    l = children.length

    while i < l
      text += getElementText(children[i])
      i++
  text

updateScriptPreview = ->
  parseScript 'name', makeScript(getElementText(scriptEditorElt), false, false), (err, script) ->
    # Remove IIFE
    script = script.substring '(function(){\nvar behavior_name = gdev.behaviors.name;'.length, script.length - '})();'.length
    generatedScriptPreviewElt.innerHTML = js_beautify script, indent_size: 2

buttonsElt.addEventListener 'click', onClickEmojiButton
scriptEditorElt.addEventListener 'keyup', updateScriptPreview

document.getElementById('TweetScriptButton').addEventListener 'click', (event) ->
  if projectNameElt.textContent == ''
    projectNameElt.focus()
    event.preventDefault()
    event.stopPropagation()
    return

  if scriptNameElt.textContent == ''
    scriptNameElt.focus()
    event.preventDefault()
    event.stopPropagation()
    return

  code = makeScript getElementText(scriptEditorElt), false, true
  commandTweet = "@gdevbot ##{projectNameElt.textContent} script #{scriptNameElt.textContent}\n#{code}"
  commandTweet = commandTweet.replace ///<mark>///g, '_'
  commandTweet = commandTweet.replace ///</mark>///g, '_'
  commandTweet = commandTweet.replace ///<br>///g, '\n'
  event.target.href = 'https://twitter.com/intent/tweet?text=' + encodeURIComponent(commandTweet)

document.getElementById('ExampleSelect').addEventListener 'change', (event) ->
  return if ! event.target.value?
  exampleCode = examples[event.target.value]
  return if ! exampleCode?

  scriptEditorElt.innerHTML = makeScript exampleCode, true, false
  updateScriptPreview()

updateScriptPreview()