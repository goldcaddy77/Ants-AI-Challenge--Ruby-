require 'set'

class Game
	# Map, as an array of arrays.
	attr_accessor :map

	# Number of current turn. If it's 0, we're in setup turn. If it's :game_over, you don't need to give any orders; instead, you can find out the number of players and their scores in this game.
	attr_accessor :turn_number

	attr_accessor :turn_start_time
	
	# Game settings. Integers.
	attr_accessor :loadtime, :turntime, :rows, :cols, :turns, :viewradius2, :attackradius2, :spawnradius2, :seed
	# Radii, unsquared. Floats.
	attr_accessor :viewradius, :attackradius, :spawnradius, :food
	
	# Number of players. Available only after game's over.
	attr_accessor :players
	# Array of scores of players (you are player 0). Available only after game's over.
	attr_accessor :score

	def time_remaining; (@turntime - (Time.now - @turn_start_time) * 1000.0).to_i; end

	# Initialize a new Game object. Arguments are streams this Game will read from and write to.
	def initialize stdin=$stdin, stdout=$stdout
		@stdin, @stdout = stdin, stdout

		@map=nil
		@turn_number=0
		
		@arr_my_ants=[]
		@set_my_ant_squares = Set.new
		@enearr_my_ants=[]
		@food = Set.new
		@log_file = File.open("out.txt", 'w')

		@did_setup=false
	end

	def log obj
		@log_file.write "[#{time_remaining.to_s}]#{obj.to_s}\n"
		@log_file.flush
	end
	
	# Returns a read-only hash of all settings.
	def settings
		{
			:loadtime => @loadtime,
			:turntime => @turntime,
			:rows => @rows,
			:cols => @cols,
			:turns => @turns,
			:viewradius2 => @viewradius2,
			:attackradius2 => @attackradius2,
			:spawnradius2 => @spawnradius2,
			:viewradius => @viewradius,
			:attackradius => @attackradius,
			:spawnradius => @spawnradius,
			:seed => @seed
		}.freeze
	end
	
	# Zero-turn logic. 
	def setup # :yields: self
		@turn_start_time = Time.now

		read_intro
		yield self
		
		@stdout.puts 'go'
		@stdout.flush
		
		@map=Array.new(@rows){|row| Array.new(@cols){|col| Square.new false, false, false, nil, row, col, self } }
		@did_setup=true
	end
	
	# Turn logic. If setup wasn't yet called, it will call it (and yield the block in it once).
	def run &b # :yields: self
		@turn_start_time = Time.now
		setup &b if !@did_setup
		
		over=false
		until over
			over = read_turn
			@turn_start_time = Time.now
			log "*** Begin turn #{turn_number.to_s} ***"
			# next if turn_number == 0

			yield self
			
			@stdout.puts 'go'
			@stdout.flush

			log "End Turn"
		end
	end

	# Internal; reads zero-turn input (game settings).
	def read_intro
		rd=@stdin.gets.strip
		warn "unexpected: #{rd}" unless rd=='turn 0'

		until((rd=@stdin.gets.strip)=='ready')
			_, name, value = *rd.match(/\A([a-z0-9]+) (\d+)\Z/)
			
			case name
			when 'loadtime'; @loadtime=value.to_i
			when 'turntime'; @turntime=value.to_i
			when 'rows'; @rows=value.to_i
			when 'cols'; @cols=value.to_i
			when 'turns'; @turns=value.to_i
			when 'viewradius2'; @viewradius2=value.to_i
			when 'attackradius2'; @attackradius2=value.to_i
			when 'spawnradius2'; @spawnradius2=value.to_i
			when 'seed'; @seed=value.to_i
			else
				warn "unexpected: #{rd}"
			end
		end
		
		@viewradius=Math.sqrt @viewradius2
		@attackradius=Math.sqrt @attackradius2
		@spawnradius=Math.sqrt @spawnradius2
	end
	
	# Internal; reads turn input (map state).
	def read_turn
		ret=false
		rd=@stdin.gets.strip
		
		if rd=='end'
			@turn_number=:game_over
			
			rd=@stdin.gets.strip
			_, players = *rd.match(/\Aplayers (\d+)\Z/)
			@players = players.to_i
			
			rd=@stdin.gets.strip
			_, score = *rd.match(/\Ascore (\d+(?: \d+)+)\Z/)
			@score = score.split(' ').map{|s| s.to_i}
			
			ret=true
		else
			_, num = *rd.match(/\Aturn (\d+)\Z/)
			@turn_number=num.to_i
		end
	
		# reset the map data
		@map.each do |row|
			row.each do |square|
				square.food=false
				square.ant=nil
				square.hill=false
			end
		end
		
		@set_my_ant_squares.clear
		@arr_my_ants=[]
		@enearr_my_ants=[]
		@food.clear
		
		until((rd=@stdin.gets.strip)=='go')
			_, type, row, col, owner = *rd.match(/(w|f|h|a|d) (\d+) (\d+)(?: (\d+)|)/)
			row, col = row.to_i, col.to_i
			owner = owner.to_i if owner
			
			case type
			when 'w'
				@map[row][col].water=true
			when 'f'
				@map[row][col].food=true
				food.add(@map[row][col])  
			when 'h'
				@map[row][col].hill=owner
			when 'a'
				a=Ant.new true, owner, @map[row][col], self
				@map[row][col].ant = a
				
				if owner==0
					arr_my_ants.push a
					set_my_ant_squares.add @map[row][col]
				else
					enearr_my_ants.push a
				end
			when 'd'
				d=Ant.new false, owner, @map[row][col], self
				@map[row][col].ant = d
			when 'r'
				# pass
			else
				warn "unexpected: #{rd}"
			end
		end

		return ret
	end
	
	# call-seq:
	#   order(ant, direction)
	#   order(row, col, direction)
	#
	# Give orders to an ant, or to whatever happens to be in the given square (and it better be an ant).
	def order ant, direction
		return if ant.has_orders?
		
		destination = ant.square.neighbor direction
		return if destination.ant?

		# tell the old and new squares that the ant moved
		ant.square.ant = nil
		destination.ant = ant
		ant.has_orders = true;

		@stdout.puts "o #{ant.row} #{ant.col} #{direction.to_s.upcase}"
		return true;
	end
	
	# Returns a set of your alive ants on the gamefield.
	def set_my_ant_squares; @set_my_ant_squares; end

	# Returns an array of your alive ants on the gamefield.
	def arr_my_ants; @arr_my_ants; end

	# Returns an array of alive enemy ants on the gamefield.
	def enearr_my_ants; @enearr_my_ants; end
	
	# If row or col are greater than or equal map width/height, makes them fit the map.
	#
	# Handles negative values correctly (it may return a negative value, but always one that is a correct index).
	#
	# Returns [row, col].
	def normalize row, col
		[row % @rows, col % @cols]
	end
end