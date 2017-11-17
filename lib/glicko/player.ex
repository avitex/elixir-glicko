defmodule Glicko.Player do
	@moduledoc """
	Provides convenience functions that handle conversions between Glicko versions one and two.

	## Usage

	Create a *v1* player with the default values for an unrated player.

		iex> Player.new_v1
		{1.5e3, 350.0}

	Create a *v2* player with the default values for an unrated player.

		iex> Player.new_v2
		{0.0, 2.014761872416068, 0.06}

	Create a player with custom values.

		iex> Player.new_v2([rating: 3.0, rating_deviation: 2.0, volatility: 0.05])
		{3.0, 2.0, 0.05}

	Convert a *v2* player to a *v1*. Note this drops the volatility.

		iex> Player.new_v2 |> Player.to_v1
		{1.5e3, 350.0}

	Convert a *v1* player to a *v2*.

		iex> Player.new_v1 |> Player.to_v2(0.06)
		{0.0, 2.014761872416068, 0.06}

	Note calling `to_v1` with a *v1* player or likewise with `to_v2` and a *v2* player
	will pass-through unchanged. The volatility arg in this case is ignored.

		iex> player_v2 = Player.new_v2
		iex> player_v2 == Player.to_v2(player_v2)
		true

	"""

	@magic_version_scale 173.7178
	@magic_version_scale_rating 1500.0

	@type t :: v1_t | v2_t

	@type v1_t :: {rating_t, rating_deviation_t}
	@type v2_t :: {rating_t, rating_deviation_t, volatility_t}

	@type version_t :: :v1 | :v2
	@type rating_t :: float
	@type rating_deviation_t :: float
	@type volatility_t :: float

	@doc """
	The recommended initial rating value for a new player.
	"""
	@spec initial_rating(version_t) :: rating_t
	def initial_rating(_version = :v1), do: 1500.0
	def initial_rating(_version = :v2), do: :v1 |> initial_rating |> scale_rating_to(:v2)

	@doc """
	The recommended initial rating deviation value for a new player.
	"""
	@spec initial_rating_deviation(version_t) :: rating_deviation_t
	def initial_rating_deviation(_version = :v1), do: 350.0
	def initial_rating_deviation(_version = :v2), do: :v1 |> initial_rating_deviation |> scale_rating_deviation_to(:v2)

	@doc """
	The recommended initial volatility value for a new player.
	"""
	@spec initial_volatility :: volatility_t
	def initial_volatility, do: 0.06

	@doc """
	Creates a new v1 player.

	If not overriden, will use the default values for an unrated player.
	"""
	@spec new_v1([rating: rating_t, rating_deviation: rating_deviation_t]) :: v1_t
	def new_v1(opts \\ []) when is_list(opts), do: {
		Keyword.get(opts, :rating, initial_rating(:v1)),
		Keyword.get(opts, :rating_deviation, initial_rating_deviation(:v1)),
	}

	@doc """
	Creates a new v2 player.

	If not overriden, will use default values for an unrated player.
	"""
	@spec new_v2([rating: rating_t, rating_deviation: rating_deviation_t, volatility: volatility_t]) :: v2_t
	def new_v2(opts \\ []) when is_list(opts), do: {
		Keyword.get(opts, :rating, initial_rating(:v2)),
		Keyword.get(opts, :rating_deviation, initial_rating_deviation(:v2)),
		Keyword.get(opts, :volatility, initial_volatility()),
	}

	@doc """
	Converts a v2 player to a v1.

	A v1 player will pass-through unchanged.

	Note the volatility field used in a v2 player will be lost in the conversion.
	"""
	@spec to_v1(player :: t) :: v1_t
	def to_v1({rating, rating_deviation}), do: {rating, rating_deviation}
	def to_v1({rating, rating_deviation, _}), do: {
		rating |> scale_rating_to(:v1),
		rating_deviation |> scale_rating_deviation_to(:v1),
	}

	@doc """
	Converts a v1 player to a v2.

	A v2 player will pass-through unchanged with the volatility arg ignored.
	"""
	@spec to_v2(player :: t, volatility :: volatility_t) :: v2_t
	def to_v2(player, volatility \\ initial_volatility())
	def to_v2({rating, rating_deviation, volatility}, _volatility), do: {rating, rating_deviation, volatility}
	def to_v2({rating, rating_deviation}, volatility), do: {
		rating |> scale_rating_to(:v2),
		rating_deviation |> scale_rating_deviation_to(:v2),
		volatility,
	}

	@doc """
	A version agnostic method for getting a player's rating.
	"""
	@spec rating(player :: t, as_version :: version_t) :: rating_t
	def rating(player, as_version \\ nil)
	def rating({rating, _}, nil), do: rating
	def rating({rating, _, _}, nil), do: rating
	def rating({rating, _}, :v1), do: rating
	def rating({rating, _}, :v2), do: rating |> scale_rating_to(:v2)
	def rating({rating, _, _}, :v1), do: rating |> scale_rating_to(:v1)
	def rating({rating, _, _}, :v2), do: rating

	@doc """
	A version agnostic method for getting a player's rating deviation.
	"""
	@spec rating_deviation(player :: t, as_version :: version_t) :: rating_deviation_t
	def rating_deviation(player, as_version \\ nil)
	def rating_deviation({_, rating_deviation}, nil), do: rating_deviation
	def rating_deviation({_, rating_deviation, _}, nil), do: rating_deviation
	def rating_deviation({_, rating_deviation}, :v1), do: rating_deviation
	def rating_deviation({_, rating_deviation}, :v2), do: rating_deviation |> scale_rating_deviation_to(:v2)
	def rating_deviation({_, rating_deviation, _}, :v1), do: rating_deviation |> scale_rating_deviation_to(:v1)
	def rating_deviation({_, rating_deviation, _}, :v2), do: rating_deviation

	@doc """
	A version agnostic method for getting a player's volatility.
	"""
	@spec volatility(player :: t, default_volatility :: volatility_t) :: volatility_t
	def volatility(player, default_volatility \\ initial_volatility())
	def volatility({_, _}, default_volatility), do: default_volatility
	def volatility({_, _, volatility}, _), do: volatility

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
	def rating_interval(player, as_version \\ nil), do: {
		rating(player, as_version) - rating_deviation(player, as_version) * 2,
		rating(player, as_version) + rating_deviation(player, as_version) * 2,
	}

	@doc """
	Scales a player's rating.
	"""
	@spec scale_rating_to(rating :: rating_t, to_version :: version_t) :: rating_t
	def scale_rating_to(rating, _version = :v1), do: (rating * @magic_version_scale) + @magic_version_scale_rating
	def scale_rating_to(rating, _version = :v2), do: (rating - @magic_version_scale_rating) / @magic_version_scale

	@doc """
	Scales a player's rating deviation.
	"""
	@spec scale_rating_deviation_to(rating_deviation :: rating_deviation_t, to_version :: version_t) :: rating_deviation_t
	def scale_rating_deviation_to(rating_deviation, _version = :v1), do: rating_deviation * @magic_version_scale
	def scale_rating_deviation_to(rating_deviation, _version = :v2), do: rating_deviation / @magic_version_scale

end
