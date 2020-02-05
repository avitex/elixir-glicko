defmodule Glicko.Result do
  @moduledoc """
  Provides convenience functions for handling a result against an opponent.

  ## Usage

      iex> opponent = %Player.V2{}
      iex> Result.new(opponent, 1.0)
      %Result{rating: 0.0, rating_deviation: 2.014761872416068, score: 1.0}
      iex> Result.new(opponent, :draw) # With shortcut
      %Result{rating: 0.0, rating_deviation: 2.014761872416068, score: 0.5}

  """

  alias Glicko.Player

  @type t :: %__MODULE__{
          rating: Player.rating(),
          rating_deviation: Player.rating_deviation(),
          score: score
        }

  @type score :: float
  @type score_shortcut :: :loss | :draw | :win

  @score_shortcut_map %{loss: 0.0, draw: 0.5, win: 1.0}
  @score_shortcuts Map.keys(@score_shortcut_map)

  defstruct [:rating, :rating_deviation, :score]

  @doc """
  Creates a new result from an opponent rating, opponent rating deviation and score.

  Values provided for the opponent rating and opponent rating deviation must be *v2* based.

  Supports passing either `:loss`, `:draw`, or `:win` as shortcuts.
  """
  @spec new(Player.rating(), Player.rating_deviation(), score | score_shortcut) :: t
  def new(opponent_rating, opponent_rating_deviation, score) when is_number(score) do
    %__MODULE__{
      rating: opponent_rating,
      rating_deviation: opponent_rating_deviation,
      score: score
    }
  end

  def new(opponent_rating, opponent_rating_deviation, score_type)
      when is_atom(score_type) and score_type in @score_shortcuts do
    score = Map.fetch!(@score_shortcut_map, score_type)
    new(opponent_rating, opponent_rating_deviation, score)
  end

  @doc """
  Creates a new result from an opponent and score.

  Supports passing either `:loss`, `:draw`, or `:win` as shortcuts.
  """
  @spec new(opponent :: Player.t(), score :: score | score_shortcut) :: t
  def new(opponent, score) do
    new(Player.rating(opponent, :v2), Player.rating_deviation(opponent, :v2), score)
  end
end
