*nyaosnippet*

INTRODUCTION

Snippets using ruby.

Requires rubywrapper plugin.

USAGE

See examples directory of this plugin to get some ideas. Mainly:
__ in a block refers to a place to jump the cursor to for changes.
_0 .. _n refer to a previously made change at a __, 0 indexed.

<Functions>

<Esc>:ruby NyaoSnippet.fill

  use text before cursor to search for a snippet

  should be an insert mapping

<Esc>:ruby NyaoSnippet.new_snippet

  create a new template using the visually selected text

  should be a visual mapping

<Mappings in .snippet buffer>

In normal mode
  <CR> will replace word under cursor with a snippet block that can execute
ruby code

In insert mode
  < or > will result in 《 and 》respectively (nyaosnippets block
delimiters)

vim:autoindent noexpandtab tabstop=8 shiftwidth=8
vim:se modifiable
vim:tw=78:et:ft=help:norl:

