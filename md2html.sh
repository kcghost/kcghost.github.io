#!/bin/bash
# Use pandoc and sed to convert Markdown to HTML
# Use sed to "extend" Markdown syntax
# The right way to do this would be lua-extend pandoc or use xmlstarlet, but I don't feel like losing my mind
set -euo pipefail
set -x

pdoc() {
	pandoc -s --template=template.html "${@}"
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
# Similar to https://github.com/RickTalken/kbdextension
# Separate begin/end is necessary for [nesting](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/kbd#representing_keystrokes_within_an_input)
kbd_shortcut() {
	sed -E 's|\[\[|<kbd>|g;s|\]\]|</kbd>|g' 
}

# Process '%foobar%' as <var>foobar</var>
var_shortcut() {
	sed -E 's|%([^%]*)%|<var>\1</var>|g'
}

input="${1}"
output="${2}"
shift
shift

# treating kbd_shortcut as postprocess is super kludgey
# but I want it available for samp blocks that will be HTML-escaped
cat "${input}" | \
var_shortcut | \
pdoc "${@}" | \
filename_to_var | \
samp_block | \
kbd_shortcut >"${output}"
