pa rubywrapper

" todo
" - autoformatting as I type? or at least after move?
" - eg: @thing = thing
" - attr_accessor :blah -> initialize(blah) @blah = blah
"
" not sure how easy this would be though... maybe a diff on line before and
" after to see the changes added to target the formatting

fu! s:setup()
ruby << RUBY
module NyaoSnippet
  LB = '《'.force_encoding Encoding::UTF_8
  RB = '》'.force_encoding Encoding::UTF_8

  class Snippet
    attr_accessor :lines, :il, :fl, :el, :col, :changes, :last_block
    def initialize lines, il, fl, el, col
      @lines = lines
      @start_line = fl
      @fl    = fl
      @il    = il
      @el    = el
      @col   = col
      @changes = []
    end

    def eval_rc original_ruby_code
      return "#{LB} #{ original_ruby_code } #{RB}" unless @changes.any?
      rc = original_ruby_code.sub(/__/, '"'+@changes.last+'"')
      subs = rc.scan(/_\d+/)
      subs.each do |s|
        change_nr = s.match(/(\d+)/)[1].to_i
        if @changes[change_nr]
          rc.sub! s, '"'+@changes[change_nr]+'"'
        else
          return "#{LB} #{ original_ruby_code } #{RB}"
        end
      end

      eval(rc)
    rescue Exception => e
      raise original_ruby_code.inspect + "--" + e.inspect
    end

    def change_next first_change=false
      if !first_change
        @changes << Vim::Buffer.current.line[@col..Ev.col('.')]
        @changes[-1] = eval_rc(@last_block)
        lines[il].insert(@col, @changes.last)
      end
      i      = nil
      lnum   = nil
      last_i = nil
      sl     = fl
      lines[il..].each_with_index do |l, li|
        @col = i = l.index(LB)
        if i
          @fl = lnum = sl+li
          @il = il+li
          @last_block = l.match(/#{LB}(.*)#{RB}/)[1]
          l.sub!(/#{LB}.*#{RB}/, '')
          # Ev.setline(lnum, l)
          render
          Ex.normal! "#{lnum}gg0#{i}l"
          break
        end
      end
      if lnum
        Ex["startinsert!"]
      else
        $exit_insert_mode_via_enter.restore
        $exit_insert_mode_via_tab.restore
        puts @changes.inspect
      end
    rescue => e
      $exit_insert_mode_via_enter.restore
      $exit_insert_mode_via_tab.restore
      raise e
    end

    # def change_next_old first_change=false
    #   if !first_change
    #     @changes << Vim::Buffer.current.line[@col..Ev.col('.')]
    #     lines[il].insert(@col, @changes.last)
    #   end
    #   i      = nil
    #   lnum   = nil
    #   last_i = nil
    #   sl     = fl
    #   lines[il..].each_with_index do |l, li|
    #     @col = i = l.index('__')
    #     if i
    #       @fl = lnum = sl+li
    #       @il = il+li
    #       l.sub!('__', '')
    #       # Ev.setline(lnum, l)
    #       render
    #       Ex.normal! "#{lnum}gg0#{i}l"
    #       break
    #     end
    #   end
    #   if lnum
    #     Ex["startinsert!"]
    #   else
    #     $exit_insert_mode_via_enter.restore
    #     $exit_insert_mode_via_tab.restore
    #     puts @changes.inspect
    #   end
    # end

    def render
      lines.each_with_index do |l, i|
        lnum = @start_line+i

        block = l.match(/#{LB}(.*)#{RB}/)&.[](1)
        if block
          l = l.sub(/#{LB}.*#{RB}/, eval_rc(block))
        end

        if lnum <= @el
          NyaoSnippet.setline(lnum, l)
        else
          # if we do this, we need to start expanding @el for further updates
          NyaoSnippet.append(lnum-1, l)
        end
      end
    end
  end

  def self.setline(lnum, line)
    Ev.setline(lnum, line.gsub('"', '\\"'))
  end

  def self.appendline(lnum, line)
    if line.is_a? Array
      line = line.map {|l| l.gsub('"', '\\"') }
    else
      line = line.gsub('"', '\\"')
    end
    Ev.append(lnum, line)
  end

  def self.fetch_snippet name
    path = "#{ENV['HOME']}/.vim/snippets/#{name}.snippet"
    if File.exist? path
      lines = File.readlines(path, chomp: true)#.map {|l| l.force_encoding Encoding::UTF_8 }
      indent = Vim::Buffer.current.line.match(/(\s*)/)[1]
      lines.map! { _1.length > 0 ? indent + _1 : '' }
    end
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
    return unless lines
    line[ri..li] = ''
    line.insert(ri, lines[0].sub(/\s*/, ''))
    lines[0] = line
    # Ev.setline('.', line)
    setline('.', line)
    # Ev.append('.', lines[1..])
    appendline('.', lines[1..])
    fl       = Ev.line('.')
    el       = fl + lines.length
    $snippet = Snippet.new(lines, 0, fl, el, cc)

    # this is a risky way to do it because if you exit insert mode some other way
    # I cannot guarentee the snippet is cleaned up
    $exit_insert_mode_via_enter.set_rhs '<Esc>:ruby $snippet.change_next<CR>'
    $exit_insert_mode_via_tab.set_rhs '<Esc>:ruby $snippet.change_next<CR>'
    $snippet.change_next true
  end
end
$exit_insert_mode_via_enter = Mapping.new 'i', '<CR>'
$exit_insert_mode_via_tab   = Mapping.new 'i', '<Tab>'
RUBY
endfu

ino <CR> <CR>
ino jp <Esc>:ruby NyaoSnippet.fill<CR>
vno \jp <Esc>:ruby NyaoSnippet.new_snippet<CR>

augroup NyaoSnippets
  autocmd!

  au BufEnter *.snippet nno <buffer> <CR> ciw__<ESC>
  au BufEnter *.snippet ino <buffer> < 《
  au BufEnter *.snippet ino <buffer> > 》
augroup END

call s:setup()
