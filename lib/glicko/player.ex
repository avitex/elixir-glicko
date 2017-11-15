defmodule Glicko.Player do
	@moduledoc """
	A convenience wrapper that handles conversions between glicko versions one and two.

	## Usage

	Create a player with the default values for an unrated player.

		iex> Player.new_v2
		%Player{version: :v2, rating: 0.0, rating_deviation: 2.014761872416068, volatility: 0.06}

	Create a player with custom values.

		iex> Player.new_v2([rating: 1500, rating_deviation: 50, volatility: 0.05])
		%Player{version: :v2, rating: 1500, rating_deviation: 50, volatility: 0.05}

	Convert a *v2* player to a *v1*. Note this drops the volatility.

		iex> Player.new_v2 |> Player.to_v1
		%Player{version: :v1, rating: 1.5e3, rating_deviation: 350.0, volatility: nil}

	Convert a *v1* player to a *v2*.

		iex> Player.new_v1 |> Player.to_v2(0.06)
		%Player{version: :v2, rating: 0.0, rating_deviation: 2.014761872416068, volatility: 0.06}

	Note calling `to_v1` with a *v1* player or likewise with `to_v2` and a *v2* player
	will pass-through unchanged. The volatility arg in this case is ignored.

		iex> player_v2 = Player.new_v2
		iex> player_v2 == Player.to_v2(player_v2)
		true

	"""

	@magic_version_scale 173.7178
	@magic_version_scale_rating 1500.0

	@default_v1_rating 1500.0
	@default_v1_rating_deviation 350.0

	@default_v2_volatility 0.06

	@type t :: v1_t | v2_t

	@type v1_t :: %__MODULE__{version: :v1, rating: float, rating_deviation: float, volatility: nil}
	@type v2_t :: %__MODULE__{version: :v2, rating: float, rating_deviation: float, volatility: float}

	defstruct [
		:version,
		:rating,
		:rating_deviation,
		:volatility,
	]

	@doc """
	Creates a new v1 player.

	If not overriden, will use default values for an unrated player.
	"""
	@spec new_v1([rating: float, rating_deviation: float]) :: v1_t
	def new_v1(opts \\ []), do: %__MODULE__{
		version: :v1,
		rating: Keyword.get(opts, :rating, @default_v1_rating),
		rating_deviation: Keyword.get(opts, :rating_deviation, @default_v1_rating_deviation),
		volatility: nil,
	}

	@doc """
	Creates a new v2 player.

	If not overriden, will use default values for an unrated player.
	"""
	@spec new_v2([rating: float, rating_deviation: float, volatility: float]) :: v2_t
	def new_v2(opts \\ []), do: %__MODULE__{
		version: :v2,
		rating: Keyword.get(opts, :rating, @default_v1_rating |> scale_rating_to(:v2)),
		rating_deviation: Keyword.get(opts, :rating_deviation, @default_v1_rating_deviation |> scale_rating_deviation_to(:v2)),
		volatility: Keyword.get(opts, :volatility, @default_v2_volatility),
	}

	@doc """
	Converts a v2 player to a v1.

	A v1 player will pass-through unchanged.

	Note the volatility field used in a v2 player will be lost in the conversion.
	"""
	@spec to_v1(player :: t) :: v1_t
	def to_v1(player = %__MODULE__{version: :v1}), do: player
	def to_v1(player = %__MODULE__{version: :v2}), do: new_v1([
		rating: player.rating |> scale_rating_to(:v1),
		rating_deviation: player.rating_deviation |> scale_rating_deviation_to(:v1),
	])

	@doc """
	Converts a v1 player to a v2.

	A v2 player will pass-through unchanged with the volatility arg ignored.
	"""
	@spec to_v2(player :: t, volatility :: float) :: v2_t
	def to_v2(player, volatility \\ @default_v2_volatility)
	def to_v2(player = %__MODULE__{version: :v2}, _volatility), do: player
	def to_v2(player = %__MODULE__{version: :v1}, volatility), do: new_v2([
		rating: player.rating |> scale_rating_to(:v2),
		rating_deviation: player.rating_deviation |> scale_rating_deviation_to(:v2),
		volatility: volatility,
	])

	@doc """
	A convenience function for summarizing a player's strength as a 95%
	confidence interval.

	The lowest value in the interval is the player's rating minus twice the RD,
	and the highest value is the player's rating plus twice the RD.
	The volatility measure does not appear in the calculation of this interval.

	An example would be if a player's rating is 1850 and the RD is 50,
	the interval would range from 1750 to 1950. We would then say that we're 95%
	confident that the player's actual strength is between 1750 and 1950.

	When a player has a low RD, the interval would be narrow, so that we would
	be 95% confident about a player’s strength being in a small interval of values.
	"""
	@spec rating_interval(player :: t) :: {rating_low :: float, rating_high :: float}
	def rating_interval(player), do: {
		player.rating - player.rating_deviation * 2,
		player.rating + player.rating_deviation * 2,
	}

	@doc """
	Scales a players rating.
	"""
	@spec scale_rating_to(rating :: float, to_version :: :v1 | :v2) :: float
	def scale_rating_to(rating, :v1), do: (rating * @magic_version_scale) + @magic_version_scale_rating
	def scale_rating_to(rating, :v2), do: (rating - @magic_version_scale_rating) / @magic_version_scale

	@doc """
	Scales a players rating deviation.
	"""
	@spec scale_rating_deviation_to(rating_deviation :: float, to_version :: :v1 | :v2) :: float
	def scale_rating_deviation_to(rating_deviation, :v1), do: rating_deviation * @magic_version_scale
	def scale_rating_deviation_to(rating_deviation, :v2), do: rating_deviation / @magic_version_scale
end
