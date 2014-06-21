require 'string.fromcodepoint'

emoji = module.exports =

  byShortcode:
    ":sunrise:":                        utf8: 0x1f305,      desc: "Once"
    ":curly_loop:":                     utf8: 0x27b0,       desc: "Always"

    ":penguin:":                        utf8: 0x1f427,      desc: "Self"
    ":baggage_claim:":                  utf8: 0x1f6c4,      desc: "Set value"
    ":key:":                            utf8: 0x1f511,      desc: "Property"
    ":scissors:":                       utf8: 0x2702,       desc: "End expression"

    ":triangular_flag_on_post:":        utf8: 0x1f6a9,      desc: "Position"
    ":car:":                            utf8: 0x1f697,      desc: "Move"
    ":o:":                              utf8: 0x2b55,       desc: "Angle"
    ":arrows_clockwise:":               utf8: 0x1f503,      desc: "Rotate"

    ":arrow_left_right:":               utf8: 0x2194,       desc: "Sprite width"
    ":arrow_up_down:":                  utf8: 0x2195,       desc: "Sprite height"

    ":question:":                       utf8: 0x2753,       desc: "Condition"
    ":twisted_rightwards_arrows:":      utf8: 0x1f500,      desc: "'Not' operator"
    ":fast_forward:":                   utf8: 0x23e9,       desc: "Block start"
    ":rewind:":                         utf8: 0x23ea,       desc: "Block end"

    ":hand:":                           utf8: 0x270b,       desc: "Touch position"
    ":wave:":                           utf8: 0x1f44b,      desc: "Touch movement"
    ":point_up_2:":                     utf8: 0x1f446,      desc: "Touch started"
    ":point_up:":                       utf8: 0x261d,       desc: "Touch ended"

    ":random:":                         utf8: 0x1f3b2,      desc: "Random"

    ":thumbsup:":                       utf8: 0x1f44d,      desc: "All good"
    ":warning:":                        utf8: 0x26a0,       desc: "Warning"

  img: (shortcode) ->
    emoji = emoji.byShortcode[shortcode]
    """<img src="/images/emoji/#{emoji.utf8.toString(16)}.png", alt="#{String.fromCodePoint(emoji.utf8)}", title="#{emoji.desc}" data-shortcode="#{shortcode}">"""

  char: (shortcode) ->
    emoji = emoji.byShortcode[shortcode]
    String.fromCodePoint(emoji.utf8)
