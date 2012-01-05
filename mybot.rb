$:.unshift File.dirname($0)
require 'game.rb'
require 'square.rb'
require 'ant.rb'
require 'imap.rb'

game = Game.new

# Perform setup
game.setup do |game|

end

# Loop through turns
game.run do |game|

#	next if game.turn_number == 0

	# game.food.each { |piece| game.log piece }

	imap = IMap.new "food", game, 10, 0.8, 0.7, false
	imap.propagate game.food, true, game.set_my_ant_squares

	game.arr_my_ants.each do |ant|

		directions = imap.get_move_directions ant.square 

		# game.log directions.inspect

		until directions.empty?
			break if ant.has_orders?
			dir = directions.pop
			ant.order dir
		end
	end	
end