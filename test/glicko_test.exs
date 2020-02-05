defmodule GlickoTest do
  use ExUnit.Case

  alias Glicko.{
    Player,
    Result
  }

  doctest Glicko

  @player %Player.V1{rating: 1500, rating_deviation: 200} |> Player.to_v2()

  @results [
    Result.new(%Player.V1{rating: 1400, rating_deviation: 30}, :win),
    Result.new(%Player.V1{rating: 1550, rating_deviation: 100}, :loss),
    Result.new(%Player.V1{rating: 1700, rating_deviation: 300}, :loss)
  ]

  @valid_player_rating_after_results 1464.06 |> Player.scale_rating_to(:v2)
  @valid_player_rating_deviation_after_results 151.52 |> Player.scale_rating_deviation_to(:v2)
  @valid_player_volatility_after_results 0.05999

  @valid_player_rating_deviation_after_no_results 200.2714
                                                  |> Player.scale_rating_deviation_to(:v2)

  describe "new rating" do
    test "with results" do
      player = Glicko.new_rating(@player, @results, system_constant: 0.5)

      assert_in_delta Player.rating(player), @valid_player_rating_after_results, 1.0e-4

      assert_in_delta Player.rating_deviation(player),
                      @valid_player_rating_deviation_after_results,
                      1.0e-4

      assert_in_delta Player.volatility(player), @valid_player_volatility_after_results, 1.0e-5
    end

    test "no results" do
      player = Glicko.new_rating(@player, [])

      assert_in_delta Player.rating_deviation(player),
                      @valid_player_rating_deviation_after_no_results,
                      1.0e-4
    end
  end

  describe "win probability" do
    test "with same ratings" do
      assert Glicko.win_probability(%Player.V1{}, %Player.V1{}) == 0.5
    end

    test "with better opponent" do
      assert Glicko.win_probability(%Player.V1{rating: 1500}, %Player.V1{rating: 1600}) <
               0.5
    end

    test "with better player" do
      assert Glicko.win_probability(%Player.V1{rating: 1600}, %Player.V1{rating: 1500}) >
               0.5
    end
  end

  describe "draw probability" do
    test "with same ratings" do
      assert Glicko.draw_probability(%Player.V1{}, %Player.V1{}) == 1
    end

    test "with better opponent" do
      assert Glicko.draw_probability(%Player.V1{rating: 1500}, %Player.V1{rating: 1600}) < 1
    end

    test "with better player" do
      assert Glicko.draw_probability(%Player.V1{rating: 1600}, %Player.V1{rating: 1500}) < 1
    end
  end
end
