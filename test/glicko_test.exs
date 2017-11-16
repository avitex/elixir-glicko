defmodule GlickoTest do
	use ExUnit.Case

	alias Glicko.{
		Player,
		GameResult,
	}

	doctest Glicko

	@player Player.new_v1([rating: 1500, rating_deviation: 200])

	@results [
		GameResult.new(Player.new_v1([rating: 1400, rating_deviation: 30]), :win),
		GameResult.new(Player.new_v1([rating: 1550, rating_deviation: 100]), :loss),
		GameResult.new(Player.new_v1([rating: 1700, rating_deviation: 300]), :loss),
	]

	@valid_player_rating_after_results 1464.06
	@valid_player_rating_deviation_after_results 151.52

	test "new rating" do
		%Player{rating: new_rating, rating_deviation: new_rating_deviation} =
			Glicko.new_rating(@player, @results, 0.5)

		assert_in_delta new_rating, @valid_player_rating_after_results, 0.1
		assert_in_delta new_rating_deviation, @valid_player_rating_deviation_after_results, 0.1
	end
end
