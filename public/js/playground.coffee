buttonsElt = document.querySelector('.PlaygroundFlex .Buttons')
textareaElt = document.querySelector('.Playground textarea')
tweetPreviewElt = document.querySelector('.TweetPreview')
generatedScriptPreviewElt = document.querySelector('.GeneratedScriptPreview')

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

  text = textareaElt.value
  emojiText = event.target.dataset.shortcode

  if textareaElt.selectionStart > 0 and text[textareaElt.selectionStart - 1] not in [ ' ', '\n' ]
    emojiText = " #{emojiText}"

  if textareaElt.selectionStart < text.length and text.length > 0 and text[textareaElt.selectionStart] not in [ ' ', '\n' ]
    emojiText = "#{emojiText} "

  textareaElt.value = text.substring(0, textareaElt.selectionStart) + emojiText + text.substring textareaElt.selectionStart

  newSelectionStart = textareaElt.selectionStart + emojiText.length
  textareaElt.setSelectionRange newSelectionStart, newSelectionStart
  updateScriptPreview()
  textareaElt.focus()

makeScript = (src, html, br) ->
  code = src
  code = code.trim().replace /\s{2,}/g, ' '
  code = code.replace /: :/g, '::'
  code = code.replace /\n/g, '<br>' if br

  for group in buttonsElt.children
    for buttonElt in group.children
      code = code.replace new RegExp(buttonElt.dataset.shortcode, 'g'), if html then emojiHTMLbyShortcodes[buttonElt.dataset.shortcode] else buttonElt.getAttribute 'alt'

  code

makeScriptTweet = (src, html=false) ->
  code = makeScript src, html, true

  if html
    "@gdevbot #<mark>Project</mark> script <mark>name</mark> #{code}"
  else
    "@gdevbot #[Project] script [name] #{code}"
  
updateScriptPreview = ->
  tweetPreviewElt.innerHTML = makeScriptTweet textareaElt.value, true

  parseScript 'name', makeScript(textareaElt.value, false, false), (err, script) ->
    # Remove IIFE
    script = script.substring '(function(){\nvar behavior_name = gdev.behaviors.name;'.length, script.length - '})();'.length
    generatedScriptPreviewElt.innerHTML = js_beautify script, indent_size: 2

buttonsElt.addEventListener 'click', onClickEmojiButton
textareaElt.addEventListener 'keyup', updateScriptPreview

document.getElementById('TweetScriptButton').addEventListener 'click', (event) ->
  commandTweet = makeScriptTweet textareaElt.value
  commandTweet = commandTweet.replace ///<mark>///g, '['
  commandTweet = commandTweet.replace ///</mark>///g, ']'
  commandTweet = commandTweet.replace ///<br>///g, '\n'
  event.target.href = 'https://twitter.com/intent/tweet?text=' + encodeURIComponent(commandTweet)

document.getElementById('ExampleSelect').addEventListener 'change', (event) ->
  return if ! event.target.value?
  exampleCode = examples[event.target.value]
  return if ! exampleCode?

  textareaElt.value = exampleCode
  updateScriptPreview()

updateScriptPreview()