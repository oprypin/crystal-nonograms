require "matrix"


enum Cell : UInt8
  Unknown, Empty, Full,
  UnknownMark, EmptyMark, FullMark

  def mark
    mark? ? self : Cell.new(value + 3)
  end
  def unmark
    mark? ? Cell.new(value - 3) : self
  end
  def mark?
    self >= UnknownMark
  end
  def known?
    self == Empty || self == Full
  end
end


class Field
  include Enumerable(Cell)

  def initialize(@row_hints : Array(Array(Int)), @col_hints : Array(Array(Int)))
    @rows = Array.new(height) { Array.new(width, Cell::Unknown) }
    @cols = Array.new(width) { Array.new(height, Cell::Unknown) }
  end
  getter row_hints, col_hints
  getter rows, cols

  def width
    @col_hints.size
  end
  def height
    @row_hints.size
  end

#   def [](row : Int, col : Int) : Cell
#     @rows[row][col]
#   end
#   def []=(row : Int, col : Int, value : Cell)
#     @rows[row][col] = value
#     @cols[col][row] = value
#   end

  def each_with_index
    @rows.each_with_index do |row, row_i|
      row.each_with_index do |c, col_i|
        yield c, row_i, col_i
      end
    end
  end
  def each
    @rows.each do |row|
      row.each do |c|
        yield c
      end
    end
  end

  def to_s
    dx, dy = {@row_hints, @col_hints}.map { |hints|
      hints.map { |line|
        line.map(&.to_s).join(' ').size
      } .max
    }
    result = Matrix.new(dy + height, dx + width*2, ' ')
    @row_hints.each_with_index do |line, row|
      s = line.map(&.to_s).join(' ')
      s.each_char_with_index do |c, i|
        result[dy + row, dx - s.size + i] = c
      end
    end
    @col_hints.each_with_index do |line, col|
      s = line.map(&.to_s).join(' ')
      s.each_char_with_index do |c, i|
        result[dy - s.size + i, dx + 1 + col*2] = c
      end
    end
    each_with_index do |c, row, col|
      out = case c
        when Cell::Full
          "▐█"
        when Cell::Empty
          " ·"
        else
          next
      end
      result[dy + row, dx + col*2], result[dy + row, dx + col*2 + 1] = out
    end
    result.rows.map(&.join).join('\n')
  end

  private def placements(hints : Array(Int), size : Int,
                         placement : Array(Int), &block : Array(Int32) ->)
    stack = placement + [placement.at(-1) { -1 } + 1 + hints[placement.size]]
    while stack[-1] <= size
      if stack.size == hints.size
        yield stack
      else
        placements(hints, size, stack.dup, &block)
      end
      stack[-1] += 1
    end
  end

  def placement_with_indices(placement : Array(Int), hints : Array(Int), size : Int)
    prev_right = 0
    placement.each_with_index do |right, pi|
      left = right - hints[pi]
      (prev_right...left).each do |i|
        yield Cell::Empty, i
      end
      (left...right).each do |i|
        yield Cell::Full, i
      end
      prev_right = right
    end
    (prev_right...size).each do |i|
      yield Cell::Empty, i
    end
  end

  def solve!
    loop do
      any_lines = false
      {% for line in {:row, :col} %}
        @{{line.id}}s.each_with_index do |line, line_i|
          hints = @{{line.id}}_hints[line_i]
          placements(hints, line.size, [] of Int32) do |placement|
            correct = true
            placement_with_indices(placement, hints, line.size) do |c, i|
              if line[i].known? && c != line[i]
                correct = false
                break
              end
            end
            if correct
              placement_with_indices(placement, hints, line.size) do |c, i|
                if !line[i].known?
                  if line[i] == Cell::Unknown
                    line[i] = c.mark
                  elsif line[i] != c.mark
                    line[i] = Cell::UnknownMark
                  end
                end
              end
            end
          end
          line.each_with_index do |c, i|
            if c.mark?
              if c != Cell::UnknownMark
                any_lines = true
                line[i] = c.unmark
                {% if line == :row %}col{% else %}row{% end %}s[i][line_i] = c.unmark
              else
                line[i] = Cell::Unknown
              end
            end
          end
        end

        yield if any_lines
      {% end %}
      break unless any_lines
    end
  end
end


rows, cols = File.read_lines(ARGV[0]).select { |line|
  !line.strip.starts_with?('#')
}.map { |line|
  line.split('|').map { |part|
    part.split.map &.to_i
  }
}


field = Field.new(rows, cols)
field.solve! do
  puts; puts field.to_s
  print "#{100 * field.count &.known? / field.size}%\r"
end
puts; puts field.to_s
