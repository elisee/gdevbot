buttonsElt = document.querySelector('.Playground .Buttons')
textareaElt = document.querySelector('.Playground textarea')

buttonsElt.addEventListener 'click', (event) ->
  return if event.target.tagName != 'IMG'
  return if ! event.target.title?

  text = textareaElt.value
  textareaElt.value = text.substring(0, textareaElt.selectionStart) + event.target.title  + text.substring textareaElt.selectionStart

  newSelectionStart = textareaElt.selectionStart + event.target.title.length + 2
  textareaElt.setSelectionRange newSelectionStart, newSelectionStart
  textareaElt.focus()

document.getElementById('MakeScriptButton').addEventListener 'click', (event) ->
  event.preventDefault()

  code = textareaElt.value
  code = code.trim().replace /\s{2,}/g, ' '
  code = code.replace /: :/g, '::'

  for buttonElt in buttonsElt.children
    code = code.replace new RegExp(buttonElt.title, 'g'), buttonElt.getAttribute 'alt'

   prompt 'Copy to Twitter, fill in the blanks, tweet!', "@gdevbot #[project] script [script] #{code}"


examples =
  setPositionOnSunrise: ":sunrise: :triangular_flag_on_post: :penguin: 20 30"
  moveRightwards: ":curly_loop: :car: :penguin: 5 0"
  moveUpThenStop: ":curly_loop: :question: :triangular_flag_on_post: :penguin: :scissors: :key: y < 100 \n:car: :penguin: 0 5"

document.getElementById('ExampleSelect').addEventListener 'change', (event) ->
  return if ! event.target.value?
  exampleCode = examples[event.target.value]
  return if ! exampleCode?

  textareaElt.value = exampleCode
