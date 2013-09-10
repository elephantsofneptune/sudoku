#!/usr/bin/ruby
# encoding: utf-8
#===============================================================================
#
#         FILE: sudoku.rb
#
#        USAGE: ./sudoku.rb
#
#  DESCRIPTION: Started with the sudoku code from Matz, and removed the
#               brute force and adding only logic to solve the problem.
#
#               On windows, to compile to exe:
#                   ocra --no-autoload sudoku.rb
#
#      OPTIONS: ---
# REQUIREMENTS: displaying text with color in a term in linux:
#
#                  gem install term-ansicolor
#                    (example on machine with no internet access: gem  install --local term-ansicolor-1.0.4.gem)
#               displaying text with color in a term in windows:
#                  gem install term-ansicolor
#                  gem install win32console (windows only)
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Mike Canann (mrc), mikecanann@gmail.com
#      COMPANY:
#      VERSION: 1.0
#      CREATED: 6/10/2013 2:13:59 PM
#     REVISION: ---
#===============================================================================


## add the current, directories
#BEGIN {
#   $LOAD_PATH.unshift(Dir.pwd) unless $LOAD_PATH.include?(Dir.pwd )
#}


require 'optparse'
require 'term/ansicolor'

begin
   require 'Win32/Console/ANSI' if (RUBY_PLATFORM.downcase =~ /win32/ || RUBY_PLATFORM.downcase =~ /mingw32/)
rescue LoadError
   raise 'You must gem install win32console to use color on Windows'
end


#TODO: mrc - make the file options work

options = {}
optparse = OptionParser.new do|opts|

   opts.banner = "Usage: sudoku.rb [--file sudoku.txt] "

   options[:file_name] = ""
   opts.on( '-f', '--file', 'File holding a sudoku puzzle to solve' ) do |f|
      options[:file_name] = f
   end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse!

#unless options[:copy_files]
#  puts "missing required argument."
#  puts "Enter `voicesms.rb -h` for help."
#  exit
#end

# An exception of this class indicates invalid input,
class Invalid < StandardError
   #print ">> ", @c.red{"INCONSISTENCY DETECTED!"}, "\n\n\n"
end

# An exception of this class indicates user aborting,
class UserAbort < StandardError
end

# An exception of this class indicates that a puzzle is over-constrained
# and that no solution is possible.
class Impossible < StandardError
end

class Array
   def union
      inject([]) { |u, a| u | a }
   end
end

class Cell

   attr_reader :possible_values, :x, :y

   def initialize(puzzle, x, y)
      @puzzle = puzzle
      @possible_values = (1..9).to_a
      @x = x
      @y = y
      @changed = false
      @linux = !(RUBY_PLATFORM.downcase =~ /win32/ || RUBY_PLATFORM.downcase =~ /mingw32/)
   end

   def remove(numbers)

     numbers = [*numbers] # this works for a single number and for ranges, too

     new_possibilities = @possible_values - numbers

     if new_possibilities == @possible_values # no change
        return false
     elsif new_possibilities.size >= 1
        @possible_values = new_possibilities
        @changed = true
        puts "#{x} #{y} value #{numbers}  - mrc remove"
        return true
     else
        return false # no change
     end
   end

  # should not be needed, but adding for debugging
  def set_possibilities(p)
     @possible_values = [*p].uniq
     @changed = true
  end

  def solved?
     @possible_values.size == 1
  end

  def value
     solved? ? @possible_values[0] : nil
  end

  def value=(number)
     remove((1..9).to_a - [*number])
  end

   #
   def to_s
      if solved?
         value.to_s
      else
         @possible_values.join()
      end
   end

   def seen_cells
      containing_houses.union
   end
   def sees?(f) # true if cells share a house
      containing_houses.include?(f)
   end
   def containing_square_pos
      (@x / 3) + 3 * (@y / 3)
   end

   def containing_square
      @puzzle.squares[containing_square_pos()]
   end

   def containing_row
      # mrc - find a way to not use a pointer to the puzzle class
      @puzzle.rows[@y]
   end

   def containing_column
      # mrc - find a way to not use a pointer to the puzzle class
      @puzzle.columns[@x]
   end

   def containing_houses
      [containing_square, containing_row, containing_column]
   end

end

class Puzzle

   attr_accessor :rows, :columns, :squares
   # These constants are used for translating between the external
   # string representation of a puzzle and the internal representation.
   ASCII = ".123456789"
   BIN = "\000\001\002\003\004\005\006\007\010\011"

   # This array holds a set of all Sudoku digits. Used below.
   AllDigits = (1..9).to_a.freeze


   # Map box number to the index of the upper-left corner of the box.
   #   ╭────────┬────────┬────────╮
   #   │ 0  1  2│ 3  4  5│ 6  7  8│
   #   │ 9 10 11│12 13 14│15 16 17│
   #   │18 19 20│21 22 23│24 25 26│
   #   ├────────┼────────┼────────┤
   #   │27 28 29│30 31 32│33 34 35│
   #   │36 37 38│39 40 41│42 43 44│
   #   │45 46 47│48 49 50│51 52 53│
   #   ├────────┼────────┼────────┤
   #   │54 55 56│57 58 59│60 61 62│
   #   │63 64 65│66 67 68│69 70 71│
   #   │72 73 74│75 76 77│78 79 80│
   #   ╰────────┴────────┴────────╯
   BoxToIndex = [0, 3, 6, 27, 30, 33, 54, 57, 60].freeze

   # This array maps from one-dimensional grid index to box number.
   # It is used in the method below. The name BoxOfIndex begins with a
   # capital letter, so this is a constant. Also, the array has been
   # frozen, so it cannot be modified.
   BoxOfIndex = [
     0,0,0,1,1,1,2,2,2,
     0,0,0,1,1,1,2,2,2,
     0,0,0,1,1,1,2,2,2,
     3,3,3,4,4,4,5,5,5,
     3,3,3,4,4,4,5,5,5,
     3,3,3,4,4,4,5,5,5,
     6,6,6,7,7,7,8,8,8,
     6,6,6,7,7,7,8,8,8,
     6,6,6,7,7,7,8,8,8
   ].freeze


   def initialize(lines)

      # This is the initialization method for the class. It is automatically
      # invoked on new Puzzle instances created with Puzzle.new. Pass the input
      # puzzle as an array of lines or as a single string. Use ASCII digits 1
      # to 9 and use the '.' character for unknown cells. Whitespace,
      # including newlines, will be stripped.

      @c = Term::ANSIColor

      if (lines.respond_to? :join)  # If argument looks like an array of lines
         s = lines.join             # Then join them into a single string
      else                          # Otherwise, assume we have a string
         s = lines.dup              # And make a private copy of it
      end


      # Remove whitespace (including newlines) from the data
      # The '!' in gsub! indicates that this is a mutator method that
      # alters the string directly rather than making a copy.
      s.gsub!(/\s/, "")  # /\s/ is a Regexp that matches any whitespace

      # Raise an exception if the input is the wrong size.
      # Note that we use unless instead of if, and use it in modifier form.
      raise Invalid, "Grid is the wrong size" unless s.size == 81

      # Check for invalid characters, and save the location of the first.
      # Note that we assign and test the value assigned at the same time.
      if s_i = s.index(/[^123456789\.]/)
         # Include the invalid character in the error message.
         # Note the Ruby expression inside #{} in string literal.
         raise Invalid, "Illegal character #{s[s_i,1]} in puzzle"
      end

      # The following two lines convert our string of ASCII characters
      # to an array of integers, using two powerful String methods.
      # The resulting array is stored in the instance variable @grid
      # The number 0 is used to represent an unknown value.
      s.tr!(ASCII, BIN)      # Translate ASCII characters into bytes
      @grid = s.unpack('c*') # Now unpack the bytes into an array of numbers


      # initialize units

      # ordering is the same as the BoxToIndex
      @cells = Array.new(9 * 9) { |i| Cell.new(self, i % 9, i / 9) }


      @grid.each_with_index{|val, i|
         # assign the known values
         if(val >= 1 && val <= 9)
            # don't assign the values  %w(_ x - 0 .)
            @cells[i].set_possibilities(val)

         end
      }

      # initialize the cell values

      # 0 to 8, 9 to 17, 18 to 26, etc
      @rows = (0..8).collect { |i| @cells[(9 * i)..(9 * i + 8)] }

      # 0 to 72, 1 to 73, 2 to 74, etc
      @columns = (0..8).collect { |i| @cells.values_at(*(0..8).collect{ |j| 9 * j + i }) }

      #   ╭─────┬─────┬─────╮
      #   │0 0 0│1 1 1│2 2 2│
      #   │0 0 0│1 1 1│2 2 2│
      #   │0 0 0│1 1 1│2 2 2│
      #   ├─────┼─────┼─────┤
      #   │3 3 3│4 4 4│5 5 5│
      #   │3 3 3│4 4 4│5 5 5│
      #   │3 3 3│4 4 4│5 5 5│
      #   ├─────┼─────┼─────┤
      #   │6 6 6│7 7 7│8 8 8│
      #   │6 6 6│7 7 7│8 8 8│
      #   │6 6 6│7 7 7│8 8 8│
      #   ╰─────┴─────┴─────╯
      @squares = (0..8).collect do |i|
         gx, gy = i % 3, i / 3
         (0..2).collect { |j| @cells[(27*gy + 3*gx + 9*j)..(27*gy + 3*gx + 9*j + 2)] }.union
      end

      @lines = @rows + @columns


      # house is any group of 9 cells that must all have different digits
      # including: rows, columns and squares
      @houses = @lines + @squares

      #   ╭───────┬───────┬───────╮
      #   │ · · · │ · · · │ · · · │
      #   │ · · · │ · · · │ · · · │
      #   │ · · · │ · · · │ · · · │
      #   ╰───────┴───────┴───────╯
      @floors = (0..2).collect { |i| (0..2).collect { |j| @rows[   3*i + j] } }

      #   ╭───────╮
      #   │ · · · │
      #   │ · · · │
      #   │ · · · │
      #   ├───────┤
      #   │ · · · │
      #   │ · · · │
      #   │ · · · │
      #   ├───────┤
      #   │ · · · │
      #   │ · · · │
      #   │ · · · │
      #   ╰───────╯
      @towers = (0..2).collect { |i| (0..2).collect { |j| @columns[3*i + j] } }

      # chute is either band/floor or a stack/tower
      @chutes = @floors + @towers


      # Make sure that the rows, columns, and boxes have no duplicates.
      raise Invalid, "Initial puzzle has duplicates" if has_duplicates?
   end

   # Return the state of the puzzle as a string of 9 lines with 9
   # characters (plus newline) each.
   def to_s
      # This method is implemented with a single line of Ruby magic that
      # reverses the steps in the initialize() method. Writing dense code
      # like this is probably not good coding style, but it demonstrates
      # the power and expressiveness of the language.
      #
      # Broken down, the line below works like this:
      # (0..8).collect invokes the code in curly braces 9 times--once
      # for each row--and collects the return value of that code into an
      # array. The code in curly braces takes a subarray of the grid
      # representing a single row and packs its numbers into a string.
      # The join() method joins the elements of the array into a single
      # string with newlines between them. Finally, the tr() method
      # translates the binary string representation into ASCII digits.
      (0..8).collect{|r| @grid[r*9,9].pack('c9')}.join("\n").tr(BIN,ASCII)
   end


   def display_all

      print "\n\n    ", @c.red{"Candidate in Red"}

      if (@linux)
         print @c.yellow{ @c.bold{" │ "}} # utf8 char
      else
         print @c.yellow{ @c.bold{" | "}} # normal pipe char
      end
      print @c.bold{@c.green{"Solved in Green"}}, "\n"

      if (@linux)
         puts("  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      else
         puts("  ======================================")
      end
      0.upto 8 do |row|             # For each row
      if(3 == row || 6 == row)
         if (@linux)
            #├─────┼─────┼─────┤
            print @c.yellow{ @c.bold{"├"}}
            print @c.yellow{ @c.bold{"─" * 29}}
            print @c.yellow{ @c.bold{"┼"}}
            print @c.yellow{ @c.bold{"─" * 29}}
            print @c.yellow{ @c.bold{"┼"}}
            print @c.yellow{ @c.bold{"─" * 29}}
            print @c.yellow{ @c.bold{"┤"}}
         else
            print @c.yellow{ @c.bold{"|"}}
            print @c.yellow{ @c.bold{"-" * 29}}
            print @c.yellow{ @c.bold{"|"}}
            print @c.yellow{ @c.bold{"-" * 29}}
            print @c.yellow{ @c.bold{"|"}}
            print @c.yellow{ @c.bold{"-" * 29}}
            print @c.yellow{ @c.bold{"|"}}
         end
         print "\n"
      end

      if (@linux)
         print @c.yellow{ @c.bold{"│"}} # utf8 char
      else
         print @c.yellow{ @c.bold{"|"}} # normal pipe char
      end

      0.upto 8 do |col|           # For each column
        index = row*9+col         # Cell index for (row,col)

            if(@cells[index].solved?)
               print @c.bold{@c.green{ "%9s" % @cells[index].to_s}}
            else
               # for displaying to the screen only change the candidate
               # characters to smaller unicode characters.
               tmp = @cells[index].to_s

               # only do the change for linux, windows doesn't handle unicode very well
               if (@linux)
                  tmp.gsub!('0','₀')
                  tmp.gsub!('1','₁')
                  tmp.gsub!('2','₂')
                  tmp.gsub!('3','₃')
                  tmp.gsub!('4','₄')
                  tmp.gsub!('5','₅')
                  tmp.gsub!('6','₆')
                  tmp.gsub!('7','₇')
                  tmp.gsub!('8','₈')
                  tmp.gsub!('9','₉')
               end

               print @c.red{ "%9s" % tmp}
            end

            if(2 == col || 5 == col || 8 == col)
               #print "\e[1;33m|\e[0m"
               print @c.yellow{@c.bold{"│"}}
            else
               print "│"
            end


         end
         print"\n"
      end
   end


   # Returns true if any row, column, or box has duplicates.
   # Otherwise returns false. Duplicates in rows, columns, or boxes are not
   # allowed in Sudoku, so a return value of true means an invalid puzzle.
   def has_duplicates?
      # uniq! returns nil if all the elements in an array are unique.
      # So if uniq! returns something then the board has duplicates.
      0.upto(8) {|row| return true if rowdigits(row).uniq! }
      0.upto(8) {|col| return true if coldigits(col).uniq! }
      0.upto(8) {|box| return true if boxdigits(box).uniq! }

      false  # If all the tests have passed, then the board has no duplicates
   end

   def solved_cells
      @cells.select { |f| f.solved? }
   end

   def unsolved_cells
      @cells.select { |f| !f.solved? }
   end


   def solved?
      @cells.all? { |f| f.solved? } && consistent?
   end

   # check each house to make sure a value exists only once
   def consistent?
      @houses.each do |house|
         found_values = []
         house.each do |f|
            f.value
            unless f.value.nil?
               if found_values.include?(f.value)
                  return false
               end
               found_values << f.value
            end
         end
      end
      return true
   end




   def direct_elimination
      rval = false
      # for each solved location, remove that candidate in each cell that this cell sees
      solved_cells.each do |cell|
         (cell.seen_cells - [cell]).each { |seen_cell|
            if(seen_cell.remove(cell.value))
               puts "#{cell.x} #{cell.y} value #{cell.value} - removing from #{seen_cell.x} #{seen_cell.y} "
               rval = true
            end
         }
      end
      rval
   end

   # naked_singles rule not needed, if only one candidate, the cell is assumed to be solved
   def naked_singles()
      0
   end


   # Hidden singles
   # one candidate is only available in this location,
   # this value is not listed anywhere else in row/column/block
   def hidden_singles()

      unsolved_cells.each do |cell|
         cell.possible_values.each do |candidate|
            # for each candidate, see if it only exists once in a containing house
            cell.containing_houses.each do |house|
               all_possible_values = Array.new()
               # gather all the values in the house
               house.each do |hc|
                  all_possible_values << hc.possible_values
               end
               # see if the can
               if(1 == all_possible_values.flatten.grep(candidate).size)
                  cell.set_possibilities(candidate)
                  puts "xy #{cell.x} #{cell.y}"
                  return(true)
               end
            end
         end
      end
      false  # couldn't find a cell value
   end

   # locked candidates
   # removes candidates from row/column
   # When in a block, if a number is only possible in one segment, then the candidate can be excluded from that row or column in the other blocks.
   #   ╭───────┬───────┬───────╮
   #   │ · · · │ · · · │ · · · │
   #   │ # # # │ x x x │ x x x │
   #   │ · · · │ · · · │ · · · │
   #   ╰───────┴───────┴───────╯
   def locked_candidates_segment_1() # also called 'locked candidates pointing'

      # if any candidates are removed, return true

      squares.each do |square|
         (1..9).each do |i|

            # get the cells that are not solved
            possible_cells = square.select { |c|
               c.possible_values.include?(i) && !c.solved?
            }

            # if there are any unsolved cells in this square
            if !possible_cells.empty?

               # get the first column of the current digit
               check_column = possible_cells.first.x
               # if the possible value only exists in this column
               if possible_cells.all? { |c| c.x == check_column } # same x-coordinate => same column
                  # remove this digit from all the cells in the column that aren't part of this square
                  columns[check_column].each { |c|
                     if(!c.solved?() && !square.include?(c))
                        return(true) if c.remove(i)
                     end
                  }
               end

               # get the first row of the current digit
               check_row = possible_cells.first.y
               # if the possible value only exists in this column
               if possible_cells.all? { |c| c.y == check_row } # same x-coordinate => same column
                  # remove this digit from all the cells in the column that aren't part of this square
                  rows[check_row].each { |c|
                     if(!c.solved?() && !square.include?(c))
                        return(true) if c.remove(i)
                     end
                  }
               end
            end
         end
      end



      return(false)
   end

   # removes candidates from block
   # When in a row or column only one block can contain a number, that number can be excluded for the other cells in that block.
   #   ╭───────┬───────┬───────╮
   #   │ x x x │ · · · │ · · · │
   #   │ # # # │ · · · │ · · · │
   #   │ x x x │ · · · │ · · · │
   #   ╰───────┴───────┴───────╯
   def locked_candidates_segment_2() # also called 'locked candidates claiming'
      # if removed any candidates, return true

      @lines.each do |line|
         (1..9).each do |i|
            possible_cells = line.select { |c|
               c.possible_values.include?(i) && !c.solved?
            }

            if !possible_cells.empty?
               check_square = possible_cells.first.containing_square_pos

               if possible_cells.all? { |c| c.containing_square_pos == check_square } # all cells are in the same square
                  squares[check_square].each { |c|
                     if(!c.solved?() && !line.include?(c))
                        return(true) if c.remove(i)
                     end
                  }
               end
            end
         end
      end

      return(false)
   end

   # Subsets
   # When a group contains two cells with the same pair of candidates (and only those two), then this candidates cannot be in another cell of the group. This is so for a row, a column or a block.
   def subset_naked_pair()
   end

   # When three cells of one group do not contain other numbers than three candidates, those numbers can be excluded from the other cells of the group
   def subset_triplet_et_quad()
   end

   # For the naked subsets (previous method: 3.1) the pairs, triplets and quads permit to exclude candidates from the other cells of the group.
   # With this method, the hidden subset, the subsets permit to exclude the other candidates from the cells wich contain them.
   # If there is N cells (2,3 or 4) containing N common numbers, then all other candidates for these cells can be excluded.
   def subset_hidden()
   end

   #
   def associated_pairs()
   end

   #
   def multiple_assiciated_pairs()
   end

   #
   def linked_candidates()
   end

   #
   def forced_chains()
   end



   # Return an array of all known values in the specified row.
   def rowdigits(row)
      # Extract the subarray that represents the row and remove all zeros.
      # Array subtraction is set difference, with duplicate removal.
      @grid[row*9,9] - [0]
   end


   # Return an array of all known values in the specified column.
   def coldigits(col)
     result = []                # Start with an empty array
     col.step(80, 9) {|i|       # Loop from col by nines up to 80
       v = @grid[i]             # Get value of cell at that index
       result << v if (v != 0)  # Add it to the array if non-zero
     }
     result                     # Return the array
   end



   # Return an array of all the known values in the specified box.
   def boxdigits(b)
     # Convert box number to index of upper-left corner of the box.
     i = BoxToIndex[b]
     # Return an array of values, with 0 elements removed.
     [
       @grid[i],    @grid[i+1],  @grid[i+2],
       @grid[i+9],  @grid[i+10], @grid[i+11],
       @grid[i+18], @grid[i+19], @grid[i+20]
     ] - [0]
   end



   #
   # Use logic to fill in as much of the puzzle as we can.
   # This method scans the puzzle, applying the rules one at a time.
   def solve()

      begin
         # these are the loop variables
         found_cell = true
         removed_candidate = false

         # Loop until we've scanned the whole board without making a change.
         while (found_cell || removed_candidate)

            # loop variables, assume no cells will be changed this time
            found_cell = false
            removed_candidate = false


            # display the puzzle with candidates
            display_all()

            if(solved?())
               puts "puzzle solved"
               return(true)
            end

            # check this puzzle
            #raise Invalid, "current puzzle has duplicates" if !consistent?
            if !consistent?
               puts "current puzzle has duplicates"
               exit
            end

            puts ">> (C)ontinue, (Q)uit?"
            proceed = gets.chomp
            puts "\n"

            if proceed.upcase == "Q"
               #puts ">> \e[31mABORTING\e[0m solving process"
               print ">> ", @c.red{"Quiting"}, " solving process\n"
               raise UserAbort
            end

            # doesn't solve any cells, only remove candidates
            if(direct_elimination())
               removed_candidate = true
               puts "direct_elimination removed candidates"
               redo # to print the screen again
            end


            boxes_solved = naked_singles()
            if(boxes_solved > 0)
               found_cell = true
               puts "naked_singles found a cell"
               redo # found a value, start again
            end

            if(true == hidden_singles())
               found_cell = true
               puts "hidden_singles found a cell"
               redo # found a value, start again
            end


            if(true == locked_candidates_segment_1())
               removed_candidate = true
               puts "locked_candidates_segment_1 removed candidate"
               redo # removed candidates  start again - but don't redo the candidates
            end

            if(true == locked_candidates_segment_2())
               removed_candidate = true
               puts "locked_candidates_segment_2 removed candidate"
               redo # removed candidates  start again - but don't redo the candidates
            end



         end

      rescue UserAbort

         puts "exiting"
         exit
      end

      puts "not able to solve the puzzle"
      return()
   end

end  # This is the end of the Puzzle class




# simple puzzle
# working
#new_puzzle = Puzzle.new("..3.2.6..9..3.5..1..18.64....81.29..7.......8..67.82....26.95..8..2.3..9..5.1.3..")

# looking for hidden singles
# working
#new_puzzle = Puzzle.new(".1...3..8...5..9.3....29....8....6.92791568344.6....7....27....3.2..1...6..3...9.")
# solution:
#914763258
#728514963
#563829417
#185437629
#279156834
#436982571
#891275346
#342691785
#657348192


# locked candidates type 1
# working
new_puzzle = Puzzle.new("....23.....4...1...5..84.9...1.7.9.2.93..6.......1.76..........8.......4.6....587")

# hard puzzle
# not yet working
#new_puzzle = Puzzle.new("4.......9.2.7.1.8...7...3...7.4.8.3.....1.....6.2.5.1...9...8...1.5.3.9.3.......4")




# working
#new_puzzle = Puzzle.new("91476325872851496356382941718543762927915683443698257189127534634269178565734819.")

new_puzzle.solve()










