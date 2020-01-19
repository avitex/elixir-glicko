defmodule Glicko.PlayerTest do
  use ExUnit.Case

  alias Glicko.Player

  doctest Player

  @valid_v1_base {1.0, 2.0}
  @valid_v2_base {1.0, 2.0, 3.0}

  test "create v1" do
    assert @valid_v1_base == Player.new_v1(rating: 1.0, rating_deviation: 2.0)
  end

  test "create v2" do
    assert @valid_v2_base == Player.new_v2(rating: 1.0, rating_deviation: 2.0, volatility: 3.0)
  end

  test "convert player v1 -> v2" do
    assert {Player.scale_rating_to(1.0, :v2), Player.scale_rating_deviation_to(2.0, :v2), 3.0} ==
             Player.to_v2(@valid_v1_base, 3.0)
  end

  test "convert player v2 -> v1" do
    assert {Player.scale_rating_to(1.0, :v1), Player.scale_rating_deviation_to(2.0, :v1)} ==
             Player.to_v1(@valid_v2_base)
  end

  test "convert player v1 -> v1" do
    assert @valid_v1_base == Player.to_v1(@valid_v1_base)
  end

  test "convert player v2 -> v2" do
    assert @valid_v2_base == Player.to_v2(@valid_v2_base)
  end

  test "scale rating v1 -> v2" do
    assert_in_delta Player.scale_rating_to(1673.7178, :v2), 1.0, 0.1
  end

  test "scale rating v2 -> v1" do
    assert_in_delta Player.scale_rating_to(1.0, :v1), 1673.7178, 0.1
  end

  test "scale rating deviation v1 -> v2" do
    assert_in_delta Player.scale_rating_deviation_to(173.7178, :v2), 1.0, 0.1
  end

  test "scale rating deviation v2 -> v1" do
    assert_in_delta Player.scale_rating_deviation_to(1.0, :v1), 173.7178, 0.1
  end

  test "rating interval" do
    assert {rating_low, rating_high} =
             [rating: 1850, rating_deviation: 50]
             |> Player.new_v2()
             |> Player.rating_interval()

    assert_in_delta rating_low, 1750, 0.1
    assert_in_delta rating_high, 1950, 0.1
  end
end
