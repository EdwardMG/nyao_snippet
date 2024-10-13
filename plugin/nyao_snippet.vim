pa rubywrapper

fu! s:setup()
ruby << RUBY
class String
  def words    = split(' ')
  def list     = split(',')
  def snake    = words.join('_')
  def key_list = list.map { ':'+_1.snake }.unlist
end

class Array
  def unlist  = join(', ')
  def unwords = join(' ')
end

module NyaoSnippet
  class Line
    LB = '《'.force_encoding Encoding::UTF_8
    RB = '》'.force_encoding Encoding::UTF_8

    attr_accessor :s, :changes
    def initialize s, changes
      @s       = s.force_encoding Encoding::UTF_8
      @changes = changes
    end

    def lb_indexes
      r = []
      i = -1
      while i = s.index(LB, i+1)
        r << i
      end
      r
    end

    def blocks
      lb_indexes.map do |i|
        s[i..s.index(RB, i+1)]
      end
    end

    def first_index_requiring_input
      lb_indexes.find {|i| requires_input? i }
    end

    def indexes_for_resolvable_non_interactive_blocks
      lb_indexes.select do |i|
        next false if block_at(i).match? /__/
        resolvable = true
        block_at(i).scan(/_(\d+)/).flatten.each do |d|
          unless changes[d.to_i]
            resolvable = false
            break
          end
        end
        resolvable
      end
    end

    def indexes_for_resolvable_interactive_blocks
      lb_indexes.select do |i|
        next false unless block_at(i).match? /__/
        resolvable = true
        block_at(i).scan(/_(\d+)/).flatten.each do |d|
          unless changes[d.to_i]
            resolvable = false
            break
          end
        end
        resolvable
      end
    end

    def requires_change?(i) = block_at(i).match? /_\d+/
    def requires_input?(i)  = block_at(i).match? /__/
    def inner_blocks        = blocks.map {|b| b[1..-2] }

    def inner_block_at(i)
      b = block_at(i)
      b[1..-2] if b
    end

    def get_block_index nr
      bs = lb_indexes
      raise "Tried to remove #{nr} from lb_indexes but it is not present. #{s.inspect}" if nr > bs.length-1
      bs[nr]
    end

    def remove_block(nr)      = remove_block_at get_block_index(nr)
    def change_block(nr, str) = change_block_at get_block_index(nr), str

    def block_at(i)
      raise "Tried to get block at #{i} but index was not on LB but `#{s[i]}`" unless s[i] == LB
      s[i..s.index(RB, i+1)]
    end

    def remove_block_at i
      raise "Tried to remove block at #{i} but index was not on LB but `#{s[i]}`" unless s[i] == LB
      s[i..s.index(RB, i+1)] = ''
      self
    end

    def change_block_at i, obj
      raise "Tried to change block at #{i} but index was not on LB but `#{s[i]}`" unless s[i] == LB
      raise "Tried to change block in #{self} but obj was #{obj.inspect}" unless obj.is_a?(Array) || obj.is_a?(String)
      if obj.is_a? Array
        indent = s.match(/(\s*)/)[1]
        obj.map! {|x| indent + x }
        @s = obj
      elsif obj.is_a?(String)
        raise "Line has been malformed #{self.inspect}" if @s.nil?
        @s[i..s.index(RB, i+1)] = obj
      end
      self
    end

    def rewrap code
      "#{LB}#{ code }#{RB}"
    end

    def eval_evalable_blocks update_input_with_most_recent_change=false
      indexes_for_resolvable_non_interactive_blocks.reverse.each do |i|
        b = block_at(i)[1..-2]

        b.scan(/_(\d+)/).flatten.each do |nr|
          change = @changes[nr.to_i]
          if change.is_a? Array
            b.gsub! '_'+nr, @changes[nr.to_i].inspect
          else
            b.gsub! '_'+nr, '"'+@changes[nr.to_i].sq+'"'
          end
        end
        change_block_at i, eval(b)
      end

      if update_input_with_most_recent_change
        i = first_index_requiring_input
        if i
          b = inner_block_at i
          b.sub!('__', '"'+@changes.last.sq+'"')
          r = eval(b)
          change_block_at i, r
          @changes[-1] = r
        end
      end

      return self
    end
  end ## Line

  LB = '《'.force_encoding Encoding::UTF_8
  RB = '》'.force_encoding Encoding::UTF_8
  class Snippet
    attr_accessor :lines, :il, :fl, :el, :col, :changes, :last_block
    def initialize lines, il, fl, el, col
      @lines      = lines
      @start_line = fl
      @fl         = fl
      @il         = il
      @el         = el
      @col        = col
      @changes    = []
    end

    def rewrap code
      "#{LB}#{ code }#{RB}"
    end

    def change_next first_change=false
      if !first_change
        # wanted to use Ev.col here, but does not play well with multibytes
        # this still seems to have problems
        bline = Vim::Buffer.current.line
        end_i = bline.length - @last_line_without_block_to_change.s.length
        change = bline[@col-1..@col-1+end_i-1]
        # TextDebug << "change: "+change.inspect

        @changes << change if change
        @last_line.changes = @changes

        @last_line.eval_evalable_blocks true
        lines[il] = @last_line.s
        lines.flatten!
        render
      end
      i      = nil
      lnum   = nil
      last_i = nil
      sl     = fl
      append_to_end = false
      lines[il..].each_with_index do |l, li|
        line = Line.new(l.clone, changes)

        i = line.indexes_for_resolvable_interactive_blocks.first
        @col = i+1 if i
        if i
          @fl           = lnum = sl+li
          @il           = il+li
          @last_block   = line.block_at i
          append_to_end = i + @last_block.length == l.length
          @last_line    = line
          @last_line_without_block_to_change = Line.new(l, changes)
          @last_line_without_block_to_change.remove_block_at i

          render
          Ex.normal! "#{lnum}gg0#{i}l"
          break
        end
        @last_line = nil
      end
      if lnum
        if append_to_end
          Ex["startinsert!"]
        else
          Ex["startinsert"]
        end
      else
        $exit_insert_mode_via_enter.restore
        $exit_insert_mode_via_tab.restore
        render # one last render in case we just added the _num for an earlier line

      end
    rescue => e
      $exit_insert_mode_via_enter.restore
      $exit_insert_mode_via_tab.restore
      raise e
    end

    def render
      lines.map!.with_index do |l, i|
        l = Line.new(l, changes)
        l.eval_evalable_blocks
        l.s
      end
      lines.flatten!
      lnum = @start_line
      lines.each_with_index do |l, i|
        if lnum < @el
          NyaoSnippet.setline(lnum, l)
        else
          NyaoSnippet.appendline(lnum-1, l)
          @el += 1 # this is ok because we do one at a time
        end
        lnum += 1
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
      lines = File.readlines(path, chomp: true)
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
    # TextDebug.clear
    # TextDebug << "start"
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
    setline('.', line)
    appendline('.', lines[1..])
    fl       = Ev.line('.')
    el       = fl + lines.length
    $snippet = Snippet.new(lines, 0, fl, el, cc)

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

" fu! s:HardReset()
"   nno <Tab> <Tab>
"   nno <CR> <CR>
" endfu
" nno \R :call <SID>HardReset()<CR>

nno \m :messages<CR>

augroup NyaoSnippets
  autocmd!

  au BufEnter *.snippet nno <buffer> <CR> ciw《 __ 》<ESC>
  au BufEnter *.snippet ino <buffer> < 《
  au BufEnter *.snippet ino <buffer> > 》
augroup END

call s:setup()

