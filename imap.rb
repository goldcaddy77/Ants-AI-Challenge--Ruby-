require 'rubygems'
require 'algorithms'

include Containers

class IMap
	attr_accessor :initialized, :additive, :blended, :ai, :base_influence, :decay, :threshold, :influence_min, :influence_max
	attr_accessor :momentum, :multiplier, :max_decrease_pct, :capped_decrease, :imap, :float_temp

	# 
	attr_accessor :propagated, :to_propagate

	# def alive?; @alive; end

	def initialize name, game, base_influence, decay, momentum, additive
		@name, @game, @decay,@momentum, @additive = @name, game, decay, momentum, additive;
		@capped_decrease = true;
		@max_decrease_pct = 1;
		@initialized = true;
		@imap = Array.new(game.rows){|row| Array.new(game.cols){|col| 0 } }
		@multiplier = base_influence > 0 ? 1 : -1
		@base_influence = base_influence.abs
		@threshold = @base_influence / 10
		@influence_max = -999999; # TODO: fix these constants
		@influence_min = 999999;
		init_performance_members

		max_heap = MaxHeap.new

		@game.log "Initializing imap"
	end

	def clear_map
		@game.log "clearing imap"
		@imap.each {|row| row.each {|col| 0 }}
	end

	def init_performance_members
		@float_temp = 0;
		@propagated = Set.new
		@to_propagate = Array.new
		# mapReturnTiles = new TreeMultiMap<Float, Tile>();
		# setTileNeighbors = new HashSet<Tile>();
		# mapReturnAims = new TreeMultiMap<Float, Aim>();
		# setAimNeighbors = new HashSet<Aim>();
		# mapCurrentNodes = new TreeMultiMap<Float, Tile>(true);
		# setTileAdded = new HashSet<Tile>();
		# setTileIgnoredHorizon = new HashSet<Tile>();
	end

	def propagate goal_agents, stop_at_invisible=true, short_circuits=Set.new
		@game.log "propagating"
		clear_map	

		goal_agents.each do |agent|
			@game.log "propagating agent #{agent.to_s} with #{short_circuits.size} short circuits"
			propagate_agent agent, stop_at_invisible, short_circuits
		end
	end

	def propagate_agent agent, stop_at_invisible, short_circuits
		@propagated.clear
		@to_propagate.clear

		to_propagate.push [agent, 0]

		while !to_propagate.empty?
			obj = to_propagate.shift
			square = obj[0]
			steps = obj[1]

			# Exit out if we hit a shortcircuit
			if short_circuits.include? square
				@game.log "(1)Found a short circuit for agent #{agent.to_s} --> #{neighbor.to_s}"
				return
			end

			next if propagated.include? square
			propagated.add square

			# Compute and add influence to this square
			influence = add_influence square, steps

			# @game.log agent.to_s + " | " + square.to_s + " | " + influence.to_s + " | " + steps.to_s

			# Add neighbors if we havent fallen below threshold
			if influence > threshold
				neighbors = square.get_movable_neighbors;

				neighbors.each do |neighbor|
				
					# if we're neighboring a short circuit square - exit
					if short_circuits.include? neighbor
						@game.log "(2)Found a short circuit for agent #{agent.to_s} --> #{neighbor.to_s}"
						return
					end

					# if(!propagated.include?(neighbor) && (!bStopAtInvisible || game.isVisible(neighbor))) {
					if(!propagated.include?(neighbor)) 
						to_propagate.push [neighbor, steps + 1];
					end
				end
			end
		end

		@game.log "No short circuit found, propagated #{propagated.size} nodes"
	end

	def add_influence square, steps
		new_influence = compute_influence_from_dist steps

		imap[square.row][square.col] += new_influence;

		@influence_max = [@influence_max, new_influence].max
		@influence_min = [@influence_min, new_influence].min
		return new_influence;
	end

	def compute_influence_from_dist distance
		return @base_influence * (@decay ** distance);
	end

	def get_move_directions square
		# map_return_directions.clear
		map_return_directions = PriorityQueue.new
		directions = square.get_movable_directions
		
		directions.each do |dir|
			neighbor = square.neighbor(dir)
			map_return_directions.push(dir, get_influence(neighbor))
			# @game.log neighbor.to_s + " | " + get_influence(neighbor).to_s
		end

		return map_return_directions
	end

	def get_influence square
		influence = imap[square.row][square.col]
		return -999999 if influence == -999999
		return 999999 if influence == 999999
		return influence * @multiplier
	end


=begin

	# private float iMap[][];
	#  private float iMapMin[][];
	# private float iMapMax[][];
	# private float iMapPrev[][];

	// Member variables for performance
	private float float_temp;
	private TreeMultiMap<Float, Tile> mapReturnTiles;
	private Set<Tile> setTileNeighbors;
	private TreeMultiMap<Float, Aim> mapReturnAims;
	private Set<Aim> setAimNeighbors;

	TreeMultiMap<Float, Tile> mapCurrentNodes;
	Set<Tile> setTileAdded;
	Set<Tile> setTileIgnoredHorizon;

	public static enum InflueceType {
		ATTRACTOR, REPELLER;
	}    


	public void setMaxDecreasePct(float fNew) {
		max_decrease_pct = fNew;
	}




	public float computeInfluenceFromPrevInfluence(float fInfluence) {
		return fInfluence * decay;
	}

	public float computeInfluenceFromDistance(int distance) {
		return new Float(base_influence * Math.pow(decay, distance));
	}

	public float addInfluence(Tile t, float fPrevWeight) {
		return addInfluence2(t, computeInfluenceFromPrevInfluence(fPrevWeight));
	}

	public float addInfluence(Tile t, int distance) {
		return addInfluence2(t, computeInfluenceFromDistance(distance));
	}

	public float addInfluence2(Tile t, float newInfluence) {
		if(additive) {
			iMap[t.getRow()][t.getCol()] += newInfluence;
		}
		else {
			iMap[t.getRow()][t.getCol()] = Math.max(iMap[t.getRow()][t.getCol()], newInfluence);
		}

		iMapMax[t.getRow()][t.getCol()] = Math.max(iMapMax[t.getRow()][t.getCol()], iMap[t.getRow()][t.getCol()]);

		influence_max = Math.max(influence_max, iMap[t.getRow()][t.getCol()]);
		influence_min = Math.min(influence_min, iMap[t.getRow()][t.getCol()]);
		return newInfluence;
	}

	public boolean hasInfluence(Tile t) {
		return iMap[t.getRow()][t.getCol()] > -999999;
	}

	public float getInfluence(Tile t) {
		return getInfluence(t.getRow(), t.getCol());
	}

	public float getInfluence(int row, int col) {
		if(blended) {
			return getInfluenceBlended(row, col);
		}
		else {
			return getInfluenceUnBlended(row, col);
		}
	}

	private float getInfluenceBlended(int row, int col) {
		return (iMap[row][col] == -999999) ? -999999 : multiplier * (iMap[row][col] + iMapMax[row][col]) / 2 ;
	}

	private float getInfluenceUnBlended(int row, int col) {
		return (iMap[row][col] == -999999) ? -999999 : multiplier * iMap[row][col];
	}

	public TreeMultiMap<Float, Tile> getMoves(Tile tile) {
		mapReturnTiles.clear();
		setTileNeighbors = tile.getMovableNeighbors(game);

		for(Tile neighbor: setTileNeighbors) {
			float_temp = getInfluence(neighbor.getRow(), neighbor.getCol());
			mapReturnTiles.put(float_temp, neighbor);
		}

		return mapReturnTiles;
	}

	public TreeMultiMap<Float, Aim> getMoveDirections(Tile tile) {
		mapReturnAims.clear();
		setAimNeighbors = tile.getMovableDirections(game);

		for(Aim direction: setAimNeighbors) {
			Tile neighbor = game.getTile(tile, direction);
			float_temp = getInfluence(neighbor.getRow(), neighbor.getCol());
			mapReturnAims.put(float_temp, direction);
		}

		return mapReturnAims;
	}

	public float getMax() {
		return influence_max * multiplier;
	}

	public float getMin() {
		return influence_min * multiplier;
	}


	public void print() 
	{
		int ROWS = game.getRows();
		int COLS = game.getCols();

		game.log("Printing Influence Map");
		game.log("Min: " + getMin());
		game.log("Max: " + getMax());

		String strRow = "", strCell = "";
		for(int r = 0; r < ROWS; r++){
			strRow = "[" + String.format("%03d", r) + "]";
			for(int c = 0; c < COLS; c++)
			{
				if(getInfluence(r, c) != -999999) {
					strCell = String.format("%03d", (int)Math.floor(getInfluence(r, c)));
				}
				else {
					strCell = "   ";
				}

				strRow += strCell;
			}
			game.log(strRow);
		}
	}	
}

=end


end