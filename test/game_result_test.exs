defmodule Glicko.GameResultTest do
	use ExUnit.Case

	alias Glicko.{
		Player,
		GameResult,
	}

	doctest GameResult

	@opponent Player.new_v2

	@valid_game_result %GameResult{opponent: @opponent, score: 0.0}

	test "create game result" do
		assert @valid_game_result == GameResult.new(@opponent, 0.0)
	end

	test "create game result with shortcut" do
		assert @valid_game_result == GameResult.new(@opponent, :loss)
	end
end
