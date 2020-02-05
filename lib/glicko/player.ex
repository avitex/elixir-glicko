defmodule Glicko.Player do
  @moduledoc """
  Provides convenience functions that handle conversions between Glicko versions one and two.

  ## Usage

  Create a *v1* player with the default values for an unrated player.

      iex> Player.new_v1
      %Player.V1{rating: 1.5e3, rating_deviation: 350.0}

  Create a *v2* player with the default values for an unrated player.

      iex> Player.new_v2
      %Player.V2{rating: 0.0, rating_deviation: 2.014761872416068, volatility: 0.06}

  Create a player with custom values.

      iex> Player.new_v2(rating: 3.0, rating_deviation: 2.0, volatility: 0.05)
      %Player.V2{rating: 3.0, rating_deviation: 2.0, volatility: 0.05}

  Convert a *v2* player to a *v1*. Note this drops the volatility.

      iex> Player.new_v2 |> Player.to_v1
      %Player.V1{rating: 1.5e3, rating_deviation: 350.0}

  Convert a *v1* player to a *v2*.

      iex> Player.new_v1 |> Player.to_v2(0.06)
      %Player.V2{rating: 0.0, rating_deviation: 2.014761872416068, volatility: 0.06}

  Note calling `to_v1` with a *v1* player or likewise with `to_v2` and a *v2* player
  will pass-through unchanged. The volatility arg in this case is ignored.

      iex> player_v2 = Player.new_v2
      iex> player_v2 == Player.to_v2(player_v2)
      true

  """

  defmodule V1 do
    @initial_rating 1500.0
    @initial_rating_deviation 350.0

    @type t :: %__MODULE__{
            rating: float(),
            rating_deviation: float()
          }

    defstruct rating: @initial_rating,
              rating_deviation: @initial_rating_deviation
  end

  defmodule V2 do
    @magic_version_scale 173.7178
    @magic_version_scale_rating 1500.0

    @v1_initial_rating 1500.0
    @v1_initial_rating_deviation 350.0

    @initial_rating (@v1_initial_rating - @magic_version_scale_rating) / @magic_version_scale
    @initial_rating_deviation @v1_initial_rating_deviation / @magic_version_scale
    @initial_volatility 0.06

    @type t :: %__MODULE__{
            rating: float(),
            rating_deviation: float(),
            volatility: float()
          }

    defstruct rating: @initial_rating,
              rating_deviation: @initial_rating_deviation,
              volatility: @initial_volatility
  end

  @magic_version_scale 173.7178
  @magic_version_scale_rating 1500.0

  @type t :: v1 | v2

  @type v1 :: V1.t()
  @type v2 :: V2.t()

  @type version :: :v1 | :v2
  @type rating :: float
  @type rating_deviation :: float
  @type volatility :: float

  @doc """
  The recommended initial volatility value for a new player.
  """
  @spec initial_volatility :: volatility
  def initial_volatility, do: 0.06

  @doc """
  Creates a new v1 player.

  If not overriden, will use the default values for an unrated player.
  """
  @spec new_v1(rating: rating, rating_deviation: rating_deviation) :: v1
  def new_v1(opts \\ []) when is_list(opts) do
    struct(V1, opts)
  end

  @doc """
  Creates a new v2 player.

  If not overriden, will use default values for an unrated player.
  """
  @spec new_v2(rating: rating, rating_deviation: rating_deviation, volatility: volatility) :: v2
  def new_v2(opts \\ []) when is_list(opts) do
    struct(V2, opts)
  end

  @doc """
  Converts a v2 player to a v1.

  A v1 player will pass-through unchanged.

  Note the volatility field used in a v2 player will be lost in the conversion.
  """
  @spec to_v1(player :: t) :: v1
  def to_v1(%V1{} = player), do: player

  def to_v1(%V2{rating: rating, rating_deviation: rating_deviation}) do
    %V1{
      rating: scale_rating_to(rating, :v1),
      rating_deviation: scale_rating_deviation_to(rating_deviation, :v1)
    }
  end

  @doc """
  Converts a v1 player to a v2.

  A v2 player will pass-through unchanged with the volatility arg ignored.
  """
  @spec to_v2(player :: t, volatility :: volatility) :: v2
  def to_v2(player, volatility \\ initial_volatility())

  def to_v2(%V1{rating: rating, rating_deviation: rating_deviation}, volatility) do
    %V2{
      rating: scale_rating_to(rating, :v2),
      rating_deviation: scale_rating_deviation_to(rating_deviation, :v2),
      volatility: volatility
    }
  end

  def to_v2(%V2{} = player, _volatility) do
    player
  end

  @doc """
  A version agnostic method for getting a player's rating.
  """
  @spec rating(player :: t, as_version :: version | nil) :: rating
  def rating(player, as_version \\ nil)
  def rating(%_{rating: rating}, nil), do: rating
  def rating(%V1{rating: rating}, :v1), do: rating
  def rating(%V2{rating: rating}, :v2), do: rating
  def rating(%V1{rating: rating}, :v2), do: rating |> scale_rating_to(:v2)
  def rating(%V2{rating: rating}, :v1), do: rating |> scale_rating_to(:v1)

  @doc """
  A version agnostic method for getting a player's rating deviation.
  """
  @spec rating_deviation(player :: t, as_version :: version | nil) :: rating_deviation
  def rating_deviation(player, as_version \\ nil)
  def rating_deviation(%V1{rating_deviation: rating_deviation}, nil), do: rating_deviation
  def rating_deviation(%V2{rating_deviation: rating_deviation}, nil), do: rating_deviation
  def rating_deviation(%V1{rating_deviation: rating_deviation}, :v1), do: rating_deviation
  def rating_deviation(%V2{rating_deviation: rating_deviation}, :v2), do: rating_deviation

  def rating_deviation(%V1{rating_deviation: rating_deviation}, :v2),
    do: rating_deviation |> scale_rating_deviation_to(:v2)

  def rating_deviation(%V2{rating_deviation: rating_deviation}, :v1),
    do: rating_deviation |> scale_rating_deviation_to(:v1)

  @doc """
  A version agnostic method for getting a player's volatility.
  """
  @spec volatility(player :: t, default_volatility :: volatility) :: volatility
  def volatility(player, default_volatility \\ initial_volatility())
  def volatility(%V1{}, default_volatility), do: default_volatility
  def volatility(%V2{volatility: volatility}, _), do: volatility

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
  @spec rating_interval(player :: t, as_version :: version | nil) ::
          {rating_low :: float, rating_high :: float}
  def rating_interval(player, as_version \\ nil) do
    {
      rating(player, as_version) - rating_deviation(player, as_version) * 2,
      rating(player, as_version) + rating_deviation(player, as_version) * 2
    }
  end

  @doc """
  Scales a player's rating.
  """
  @spec scale_rating_to(rating :: rating, to_version :: version) :: rating
  def scale_rating_to(rating, _version = :v1),
    do: rating * @magic_version_scale + @magic_version_scale_rating

  def scale_rating_to(rating, _version = :v2),
    do: (rating - @magic_version_scale_rating) / @magic_version_scale

  @doc """
  Scales a player's rating deviation.
  """
  @spec scale_rating_deviation_to(rating_deviation :: rating_deviation, to_version :: version) ::
          rating_deviation
  def scale_rating_deviation_to(rating_deviation, _version = :v1),
    do: rating_deviation * @magic_version_scale

  def scale_rating_deviation_to(rating_deviation, _version = :v2),
    do: rating_deviation / @magic_version_scale
end
