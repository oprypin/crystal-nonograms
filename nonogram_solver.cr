require "matrix"

enum Cell
  Unknown = -1, Empty, Full
end

class Field < Matrix(Cell)
  def initialize(@row_hints : Array(Array(Int)), @col_hints : Array(Array(Int)))
    super(@row_hints.size, @col_hints.size, Cell::Unknown)
#     @cells = Array(Cell).new(width*height, Cell::Unknown)
  end
  getter col_hints, row_hints

#   getter cells
  def width
    @col_hints.size
  end
  def height
    @row_hints.size
  end

  abstract struct Line
    abstract def initialize(field : Field, index : Int)
    abstract def [](index : Int) : Cell
    abstract def []=(index : Int, value : Cell) : Void
    abstract def size : Int
    abstract def hints : Array(Int)
    def each : Cell
      (0...size).each do |i|
        yield self[i]
      end
    end
    def to_a : Array(Cell)
      Array.new(size) { |i| self[i] }
    end
  end

  struct Row < Line
    def initialize(@field : Field, index : Int)
      @start = field.width * index
      @size = field.width
      @hints = @field.row_hints[index]
    end
    def [](index : Int)
      @field[@start + index]
    end
    def []=(index : Int, value : Cell)
      @field[@start + index] = value
    end
    getter size
    getter hints
    def each : Cell
      (@start ... @start+size).each do |i|
        yield @field[i]
      end
    end
  end

  struct Col < Line
    def initialize(@field : Field, index : Int)
      @start = index
      @size = field.height
      @hints = @field.col_hints[index]
    end
    def [](index : Int)
      @field[@start + @field.width*index]
    end
    def []=(index : Int, value : Cell)
      @field[@start + @field.width*index] = value
    end
    getter size
    getter hints
    def each : Cell
      index = @start
      (0 ... size).each do |i|
        yield @field[index]
        index += @field.width
      end
    end
    def to_a : Array(Cell)
      index = @start
      Array.new(size) { |i|
        c = @field[index]
        index += @field.width
        c
      }
    end
  end

  def row(index : Int)
    Row.new(self, index)
  end
  def col(index : Int)
    Col.new(self, index)
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
    yield
    undecided = Cell.new(12345)
    any = true
    while any
      any = false
      {:rows, :cols}.each do |kind|
        (0 ... (kind == :rows ? height : width)).each do |i|
          fline = kind == :rows ? row i : col i
          line, hints = fline.to_a, fline.hints
          placements(hints, line.size, [] of Int32) do |placement|
            correct = true
            placement_with_indices(placement, hints, line.size) do |c, i|
              if fline[i] != Cell::Unknown
                if c != fline[i]
                  correct = false
                  break
                end
              end
            end
            if correct
              placement_with_indices(placement, hints, line.size) do |c, i|
                if fline[i] == Cell::Unknown
                  if line[i] == Cell::Unknown
                    line[i] = c
                  elsif line[i] != c
                    line[i] = undecided
                  end
                end
              end
            end
          end
          y = false
          line.each_with_index do |c, i|
            if c != undecided && fline[i] != c
              y = any = true
              fline[i] = c
            end
          end
          yield if y
          #break
        end
      end
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
  puts field.to_s
end

