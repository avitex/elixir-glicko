defmodule Glicko.Result do
  @moduledoc """
  Provides convenience functions for handling a result against an opponent.

  ## Usage

      iex> opponent = Player.new_v2
      iex> Result.new(opponent, 1.0)
      {0.0, 2.014761872416068, 1.0}
      iex> Result.new(opponent, :draw) # With shortcut
      {0.0, 2.014761872416068, 0.5}

  """

  alias Glicko.Player

  @type t :: {Player.rating(), Player.rating_deviation(), score}

  @type score :: float
  @type score_shortcut :: :loss | :draw | :win

  @score_shortcut_map %{loss: 0.0, draw: 0.5, win: 1.0}
  @score_shortcuts Map.keys(@score_shortcut_map)

  @doc """
  Creates a new result from an opponent rating, opponent rating deviation and score.

  Values provided for the opponent rating and opponent rating deviation must be *v2* based.

  Supports passing either `:loss`, `:draw`, or `:win` as shortcuts.
  """
  @spec new(Player.rating(), Player.rating_deviation(), score | score_shortcut) :: t
  def new(opponent_rating, opponent_rating_deviation, score) when is_number(score) do
    {opponent_rating, opponent_rating_deviation, score}
  end

  def new(opponent_rating, opponent_rating_deviation, score_type)
      when is_atom(score_type) and score_type in @score_shortcuts do
    {opponent_rating, opponent_rating_deviation, Map.fetch!(@score_shortcut_map, score_type)}
  end

  @doc """
  Creates a new result from an opponent and score.

  Supports passing either `:loss`, `:draw`, or `:win` as shortcuts.
  """
  @spec new(opponent :: Player.t(), score :: score | score_shortcut) :: t
  def new(opponent, score) do
    new(Player.rating(opponent, :v2), Player.rating_deviation(opponent, :v2), score)
  end

  @doc """
  Convenience function for accessing an opponent's rating.
  """
  @spec opponent_rating(result :: t()) :: Player.rating()
  def opponent_rating(_result = {rating, _, _}), do: rating

  @doc """
  Convenience function for accessing an opponent's rating deviation.
  """
  @spec opponent_rating_deviation(result :: t()) :: Player.rating_deviation()
  def opponent_rating_deviation(_result = {_, rating_deviation, _}), do: rating_deviation

  @doc """
  Convenience function for accessing the score.
  """
  @spec score(result :: t()) :: score
  def score(_result = {_, _, score}), do: score
end
