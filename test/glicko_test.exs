defmodule GlickoTest do
	use ExUnit.Case

	alias Glicko.{
		Player,
		Result,
	}

	doctest Glicko

	@player Player.new_v1([rating: 1500, rating_deviation: 200]) |> Player.to_v2

	@results [
		{{1400, 30}, 1.0},
		Result.new({1550, 100}, :loss),
		Result.new(Player.new_v1([rating: 1700, rating_deviation: 300]), :loss),
	]

	@valid_player_rating_after_results 1464.06 |> Player.scale_rating_to(:v2)
	@valid_player_rating_deviation_after_results 151.52 |> Player.scale_rating_deviation_to(:v2)
	@valid_player_volatility_after_results 0.05999

	@valid_player_rating_deviation_after_no_results 200.2714 |> Player.scale_rating_deviation_to(:v2)

	test "new rating (with results)" do
		%Player{rating: new_rating, rating_deviation: new_rating_deviation, volatility: new_volatility} =
			Glicko.new_rating(@player, @results, [system_constant: 0.5])

		assert_in_delta new_rating, @valid_player_rating_after_results, 1.0e-4
		assert_in_delta new_rating_deviation, @valid_player_rating_deviation_after_results, 1.0e-4
		assert_in_delta new_volatility, @valid_player_volatility_after_results, 1.0e-5
	end

	test "new rating (no results)" do
		%Player{rating_deviation: new_rating_deviation} = Glicko.new_rating(@player, [])

		assert_in_delta new_rating_deviation, @valid_player_rating_deviation_after_no_results, 1.0e-4
	end
end
