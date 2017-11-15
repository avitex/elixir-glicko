defmodule Glicko.GameResult do
	@moduledoc """
	This module provides a representation of a game result against an opponent.

	## Usage

		iex> opponent = Player.new_v2
		iex> GameResult.new(opponent, 0.0)
		%GameResult{score: 0.0, opponent: %Player{version: :v2, rating: 0.0, rating_deviation: 2.014761872416068, volatility: 0.06}}
		iex> GameResult.new(opponent, :win) # With shortcut
		%GameResult{score: 1.0, opponent: %Player{version: :v2, rating: 0.0, rating_deviation: 2.014761872416068, volatility: 0.06}}

	"""

	alias Glicko.Player

	defstruct [
		:score,
		:opponent,
	]

	@type t :: %__MODULE__{score: float, opponent: Player.t}

	@type result_type_t :: :loss | :draw | :win

	@result_type_map %{loss: 0.0, draw: 0.5, win: 1.0}

	@doc """
	Creates a new GameResult against an opponent.

	Supports passing either `:loss`, `:draw`, or `:win` as shortcuts.
	"""
	@spec new(opponent :: Player.t, result_type_t | float) :: t
	def new(opponent, result_type) when is_atom(result_type) and result_type in [:loss, :draw, :win] do
		new(opponent, Map.fetch!(@result_type_map, result_type))
	end
	def new(opponent, score) when is_number(score), do: %__MODULE__{
		score: score,
		opponent: opponent,
	}
end
