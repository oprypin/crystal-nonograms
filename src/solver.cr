require "./nonogram"

rows, cols = File.read_lines(ARGV[0]).select { |line|
  !line.strip.starts_with?('#')
}.map { |line|
  line.split('|').map { |part|
    part.split.map &.to_i
  }
}

field = Nonogram.new(rows, cols)
puts field.solve! {
  puts; puts field
  print "#{100 * field.count &.known? / field.size}%\r"
}
