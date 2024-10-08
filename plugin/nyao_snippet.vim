pa rubywrapper

fu! s:setup()
ruby << RUBY
module NyaoSnippet
  class Snippet
    attr_accessor :lines, :il, :fl, :el, :col
    def initialize lines, il, fl, el, col
      @lines = lines
      @fl    = fl
      @il    = il
      @el    = el
      @col   = col
    end

    def change_next
      i      = nil
      lnum   = nil
      last_i = nil
      sl     = fl
      lines[il..].each_with_index do |l, li|
        @col = i = l.index('__')
        if i
          @fl = lnum = sl+li
          @il = il+li
          l.sub!('__', '')
          Ev.setline(lnum, l)
          Ex.normal! "#{lnum}gg0#{i}l"
          break
        end
      end
      if lnum
        Ex["startinsert!"]
      else
        $exit_insert_mode_via_enter.restore
        $exit_insert_mode_via_tab.restore
      end
    end
  end

  def self.fetch_snippet name
    lines = File.readlines("#{ENV['HOME']}/.vim/snippets/#{name}.snippet", chomp: true)
    indent = Vim::Buffer.current.line.match(/(\s*)/)[1]
    lines.map! { _1.length > 0 ? indent + _1 : '' }
  end

  def self.new_snippet
    trigger = Ev.input("Snippet trigger: ")
    path    = "#{ENV['HOME']}/.vim/snippets/#{trigger}.snippet"
    lines   = VisualSelection.new.outer
    indent = lines[0].match(/(\s*)/)[1]
    lines.each { _1.sub! indent, '' }
    File.write(path, lines.join("\n"))
    Ex.edit path
  end

  def self.fill
    cc           = Ev.col('.')
    line         = Ev.getline('.')
    ri           = (line.rindex(/[\s\.]/, cc-1) || -1)+1
    li           = cc-1
    cmd          = line[ri..li]
    lines        = fetch_snippet cmd
    line[ri..li] = ''
    line.insert(ri, lines[0].sub(/\s*/, ''))
    lines[0] = line
    Ev.setline('.', line)
    Ev.append('.', lines[1..])
    fl       = Ev.line('.')
    el       = fl + lines.length
    $snippet = Snippet.new(lines, 0, fl, el, cc)

    # this is a risky way to do it because if you exit insert mode some other way
    # I cannot guarentee the snippet is cleaned up
    $exit_insert_mode_via_enter.set_rhs '<Esc>:ruby $snippet.change_next<CR>'
    $exit_insert_mode_via_tab.set_rhs '<Esc>:ruby $snippet.change_next<CR>'
    $snippet.change_next
  end
end
$exit_insert_mode_via_enter = Mapping.new 'i', '<CR>'
$exit_insert_mode_via_tab   = Mapping.new 'i', '<Tab>'
RUBY
endfu

ino <CR> <CR>
ino jp <Esc>:ruby NyaoSnippet.fill<CR>
vno jp <Esc>:ruby NyaoSnippet.new_snippet<CR>

augroup NyaoSnippets
  autocmd!

  au BufEnter *.snippet nno <CR> ciw__<ESC>
augroup END

call s:setup()
