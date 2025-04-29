#!/bin/bash
# Use pandoc and sed to convert Markdown to HTML
# Use sed to "extend" Markdown syntax
# The right way to do this would be lua-extend pandoc or use xmlstarlet, but I don't feel like losing my mind
set -euo pipefail

pdoc() {
	pandoc -s --template=template.html --from markdown "${@}"
}

# postprocess codeblock with filename= attribute to include
# the filename as a <var> inside the pre block
# Arguably this is a stretch of what var *means* semantically speaking
# But what is a filename but a variable whose contents are a file? :mindblown:
# It's important to postprocess so pandoc can take care of
# HTML-escaping the contents of the block
# ```{filename=/path/to/file}
# <pre><var>/path/to/file</var><code>...</code></pre>
filename_to_var() {
	# TODO: Allow for additonal attributes/classes
	sed -E 's|<pre data-filename=\"([^\"]*)\">|<pre><var>\1</var>\n|g'
}

# postprocess codeblock with sample class as a sample rather than a codeblock
# ```sample
# <pre><samp>...</samp></pre>
samp_block() {
	# TODO: Allow for additonal attributes/classes
	# select pattern range including entire matching pre block
	# replace code tags with samp tags
	sed -E '/<pre class=\"sample\">/,/<\/pre>/ '\
's|code>|samp>|g'
}

# Process '[[foobar]]' as <kbd>foobar</kbd>
# Only operate *outside* of <code> blocks
# Similar to https://github.com/RickTalken/kbdextension
# Separate begin/end is necessary for [nesting](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/kbd#representing_keystrokes_within_an_input)
kbd_shortcut() {
	sed -E '/^<code>/,/<\/code>/!s|\[\[|<kbd>|g;/^<code>/,/<\/code>/!s|\]\]|</kbd>|g'
}

# Process '%foobar%' as <var>foobar</var>
var_shortcut() {
	sed -E 's|%([^%]*)%|<var>\1</var>|g'
}

insert_toc() {
	sed -E "s|\{table-of-contents\}|<nav>${toc//$'\n'/\\n}</nav>|g"
}

# Pandoc supports creating a figcaption using the alt text:
# https://pandoc.org/MANUAL.html#extension-implicit_figures
# But alt and figcaption are [two different things](https://thoughtbot.com/blog/alt-vs-figcaption)
# Preprocess the following instead:
# ![alt_text](path/to/image.jpg "title_text" "caption_text")
figure_caption() {
	sed -E 's|!\[([^]]*)\]\(([^.]*)\.(jpg\|png) \"([^"]*)\" \"([^"]*)\"\)|'\
'<figure><img alt="\1" src="\2.\3" title="\4"><figcaption>\5</figcaption></figure>|g'
}

figure_caption_video() {
	sed -E 's|!\[([^]]*)\]\(([^.]*)\.(mp4\|webm) \"([^"]*)\" \"([^"]*)\"\)|'\
'<figure><video loop autoplay muted title="\4"><source src="\2.\3"/><p>Your browser does not support embedded video.</p><p>\1</p></video><figcaption>\5</figcaption></figure>|g'
}

input="${1}"
output="${2}"
shift
shift

# first grab the toc contents to insert
echo "\$table-of-contents\$" >/tmp/toc.html
toc=$(pandoc -s --toc --template=/tmp/toc.html "${input}")

# treating kbd_shortcut as postprocess is super kludgey
# but I want it available for samp blocks that will be HTML-escaped
cat "${input}" | \
figure_caption | \
figure_caption_video | \
pdoc "${@}" | \
filename_to_var | \
samp_block | \
insert_toc | \
kbd_shortcut >"${output}"
