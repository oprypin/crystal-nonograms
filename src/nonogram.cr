class Nonogram
  enum Cell : Int8
    Pending = -2, Unknown = -1, Empty = 0, Full = 1

    def known?
      self >= Empty
    end
  end

  include Enumerable(Cell)
  def_clone

  enum State
    Solved, CantSolve, Invalid
  end

  def initialize(@row_hints : Array(Array(Int32)), @col_hints : Array(Array(Int32)))
    @rows = Array.new(height) { Array.new(width, Cell::Unknown) }
    @cols = Array.new(width) { Array.new(height, Cell::Unknown) }
  end
  getter row_hints, col_hints
  getter rows : Array(Array(Cell)), cols : Array(Array(Cell))

  def width
    @col_hints.size
  end
  def height
    @row_hints.size
  end

  def [](row : Int32, col : Int32) : Cell
    @rows[row][col]
  end
  def []=(row : Int32, col : Int32, value : Cell)
    @rows[row][col] = value
    @cols[col][row] = value
  end

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

  def to_s(io)
    dx, dy = {@row_hints, @col_hints}.map { |hints|
      hints.map { |line|
        line.map(&.to_s).join(' ').size
      } .max
    }
    result = Array.new(dy + height) { Array.new(dx + width*2) { ' ' } }
    @row_hints.each_with_index do |line, row_i|
      s = line.map(&.to_s).join(' ')
      s.each_char_with_index do |c, i|
        result[dy + row_i][dx - s.size + i] = c
      end
    end
    @col_hints.each_with_index do |line, col_i|
      s = line.map(&.to_s).join(' ')
      s.each_char_with_index do |c, i|
        result[dy - s.size + i][dx + 1 + col_i*2] = c
      end
    end
    each_with_index do |c, row_i, col_i|
      out = case c
        when Cell::Full
          "▐█"
        when Cell::Empty
          " ·"
        else
          next
      end
      result[dy + row_i][dx + col_i*2], result[dy + row_i][dx + col_i*2 + 1] = out
    end
    io << result.map(&.join).join('\n')
  end

  private def placements(hints : Array(Int32), size : Int32,
                         placement = [] of Int32, &block : Array(Int32) ->)
    if hints.size == 0
      yield [] of Int32
      return
    end
    stack = placement + [placement.last { -1 } + 1 + hints[placement.size]]
    while stack[-1] <= size
      if stack.size == hints.size
        yield stack
      else
        placements(hints, size, stack.dup, &block)
      end
      stack[-1] += 1
    end
  end

  def placement_with_indices(placement : Array(Int32), hints : Array(Int32), size : Int32)
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

  {% for yld in [true, false] %}
  def solve!(complex = true) : State
    todo = Set({Int32, Int32}).new
    height.times { |i| todo << {i, -1} }
    width.times { |i| todo << {-1, i} }
    contr_todo = Array({Int32, Int32, Cell}).new

    loop do
      until todo.empty?
        todo_item = todo.first
        todo.delete todo_item
        row_i, col_i = todo_item
        if row_i >= 0
          line, hints = @rows[row_i], @row_hints[row_i]
        else
          line, hints = @cols[col_i], @col_hints[col_i]
        end

        try = line.map { |c| c.known? ? c : Cell::Pending }
        any_possible = false
        placements(hints, line.size, [] of Int32) do |placement|
          possible = true
          placement_with_indices(placement, hints, line.size) do |c, i|
            if c != line[i] != Cell::Unknown
              possible = false
              break
            end
          end
          if possible
            any_possible = true
            placement_with_indices(placement, hints, line.size) do |c, i|
              if line[i] == Cell::Unknown
                if try[i] == Cell::Pending
                  try[i] = c
                elsif try[i] != c
                  try[i] = Cell::Unknown
                end
              end
            end
          end
        end
        return State::Invalid if !any_possible

        any = false
        try.each_with_index do |c, i|
          if line[i] != c && c.known?
            if row_i >= 0
              self[row_i, i] = c
              todo << {-1, i}
            else
              self[i, col_i] = c
              todo << {i, -1}
            end
            any = true
          end
        end
        if any
          contr_todo.clear
          {% if yld %}yield todo_item{% end %}
        end
      end
      break unless complex

      if contr_todo.empty?
        each_with_index do |c, row_i, col_i|
          if c == Cell::Unknown
            contr_todo << {row_i, col_i, Cell::Full} << {row_i, col_i, Cell::Empty}
          end
        end
        break if contr_todo.empty?

        contr_todo.sort_by! do |(row_i, col_i, c)|
          {
            {@rows[row_i], @row_hints[row_i]},
            {@cols[col_i], @col_hints[col_i]},
          }.map { |(line, hints)|
            now = line.count c
            total = (c == Cell::Full ? hints.sum : line.size - hints.sum)
            now.to_f/total
          } .sum
        end
      end

      while todo.empty?
        return State::CantSolve if contr_todo.empty?

        row_i, col_i, fc = contr_todo.pop
        field = clone
        field[row_i, col_i] = fc
        state = field.solve!(complex: false)
        if state == State::Invalid
          self[row_i, col_i] = (fc == Cell::Full ? Cell::Empty : Cell::Full)
          todo << {row_i, -1} << {-1, col_i}
        end
      end
    end

    each do |c|
      unless c.known?
        return State::CantSolve
      end
    end
    return State::Solved
  end
  {% end %}
end
