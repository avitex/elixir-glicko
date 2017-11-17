defmodule Glicko.ResultTest do
	use ExUnit.Case

	alias Glicko.{
		Player,
		Result,
	}

	doctest Result

	@opponent Player.new_v2

	@valid_game_result Result.new(@opponent, 0.0)

	test "create game result" do
		assert @valid_game_result == Result.new(@opponent, 0.0)
	end

	test "create game result with shortcut" do
		assert @valid_game_result == Result.new(@opponent, :loss)
	end
end
