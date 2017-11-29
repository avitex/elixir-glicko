defmodule Glicko do
	@moduledoc """
	Provides the implementation of the Glicko rating system.

	See the [specification](http://www.glicko.net/glicko/glicko2.pdf) for implementation details.

	## Usage

	Get a player's new rating after a series of matches in a rating period.

		iex> results = [Result.new(Player.new_v1([rating: 1400, rating_deviation: 30]), :win),
		...> Result.new(Player.new_v1([rating: 1550, rating_deviation: 100]), :loss),
		...> Result.new(Player.new_v1([rating: 1700, rating_deviation: 300]), :loss)]
		iex> player = Player.new_v1([rating: 1500, rating_deviation: 200])
		iex> Glicko.new_rating(player, results, [system_constant: 0.5])
		{1464.0506705393013, 151.51652412385727}

	Get a player's new rating when they haven't played within a rating period.

		iex> player = Player.new_v1([rating: 1500, rating_deviation: 200])
		iex> Glicko.new_rating(player, [], [system_constant: 0.5])
		{1.5e3, 200.27141669877065}

	"""

	alias __MODULE__.{
		Player,
		Result,
	}

	@default_system_constant 0.8
	@default_convergence_tolerance 1.0e-7

	@type new_rating_opts :: [system_constant: float, convergence_tolerance: float]

	@doc """
	Generate a new rating from an existing rating and a series (or lack) of results.

	Returns the updated player with the same version given to the function.
	"""
	@spec new_rating(player :: Player.t, results :: list(Result.t), opts :: new_rating_opts) :: Player.t
	def new_rating(player, results, opts \\ [])
	def new_rating(player, results, opts) when tuple_size(player) == 3 do
		do_new_rating(player, results, opts)
	end
	def new_rating(player, results, opts) when tuple_size(player) == 2 do
		player
		|> Player.to_v2
		|> do_new_rating(results, opts)
		|> Player.to_v1
	end

	defp do_new_rating({player_r, player_pre_rd, player_v}, [], _) do
		player_post_rd = calc_player_post_base_rd(:math.pow(player_pre_rd, 2), player_v)

		{player_r, player_post_rd, player_v}
	end
	defp do_new_rating({player_pre_r, player_pre_rd, player_pre_v}, results, opts) do
		sys_const = Keyword.get(opts, :system_constant, @default_system_constant)
		conv_tol = Keyword.get(opts, :convergence_tolerance, @default_convergence_tolerance)

		# Initialization (skips steps 1, 2 and 3)
		player_pre_rd_sq = :math.pow(player_pre_rd, 2)
		{variance_est, results_effect} = result_calculations(results, player_pre_r)
		# Step 4
		delta = calc_delta(results_effect, variance_est)
		# Step 5.1
		alpha = calc_alpha(player_pre_v)
		# Step 5.2
		k = calc_k(alpha, delta, player_pre_rd_sq, variance_est, sys_const, 1)
		{initial_a, initial_b} = iterative_algorithm_initial(
			alpha, delta, player_pre_rd_sq, variance_est, sys_const, k
		)
		# Step 5.3
		initial_fa = calc_f(alpha, delta, player_pre_rd_sq, variance_est, sys_const, initial_a)
		initial_fb = calc_f(alpha, delta, player_pre_rd_sq, variance_est, sys_const, initial_b)
		# Step 5.4
		a = iterative_algorithm_body(
			alpha, delta, player_pre_rd_sq, variance_est, sys_const, conv_tol,
			initial_a, initial_b, initial_fa, initial_fb
		)
		# Step 5.5
		player_post_v = calc_new_player_volatility(a)
		# Step 6
		player_post_base_rd = calc_player_post_base_rd(player_pre_rd_sq, player_post_v)
		# Step 7
		player_post_rd = calc_new_player_rating_deviation(player_post_base_rd, variance_est)
		player_post_r = calc_new_player_rating(results_effect, player_pre_r, player_post_rd)

		{player_post_r, player_post_rd, player_post_v}
	end

	defp result_calculations(results, player_pre_r) do
		{variance_estimate_acc, result_effect_acc} =
			Enum.reduce(results, {0.0, 0.0}, fn result, {variance_estimate_acc, result_effect_acc} ->
				opponent_rd_g =
					result
					|> Result.opponent_rating_deviation
					|> calc_g

				win_probability = calc_e(player_pre_r, Result.opponent_rating(result), opponent_rd_g)

				{
					variance_estimate_acc + :math.pow(opponent_rd_g, 2) * win_probability * (1 - win_probability),
					result_effect_acc + opponent_rd_g * (Result.score(result) - win_probability)
				}
			end)

		{:math.pow(variance_estimate_acc, -1), result_effect_acc}
	end

	defp calc_delta(results_effect, variance_est) do
		results_effect * variance_est
	end

	defp calc_f(alpha, delta, player_pre_rd_sq, variance_est, sys_const, x) do
		:math.exp(x) *
		(:math.pow(delta, 2) - :math.exp(x) - player_pre_rd_sq - variance_est) /
		(2 * :math.pow(player_pre_rd_sq + variance_est + :math.exp(x), 2)) -
		(x - alpha) / :math.pow(sys_const, 2)
	end

	defp calc_alpha(player_pre_v) do
		:math.log(:math.pow(player_pre_v, 2))
	end

	defp calc_new_player_volatility(a) do
		:math.exp(a / 2)
	end

	defp calc_new_player_rating(results_effect, player_pre_r, player_post_rd) do
		player_pre_r + :math.pow(player_post_rd, 2) * results_effect
	end

	defp calc_new_player_rating_deviation(player_post_base_rd, variance_est) do
		1 / :math.sqrt(1 / :math.pow(player_post_base_rd, 2) + 1 / variance_est)
	end

	defp calc_player_post_base_rd(player_pre_rd_sq, player_pre_v) do
		:math.sqrt((:math.pow(player_pre_v, 2) + player_pre_rd_sq))
	end

	defp iterative_algorithm_initial(alpha, delta, player_pre_rd_sq, variance_est, sys_const, k) do
		initial_a = alpha
		initial_b =
			if :math.pow(delta, 2) > player_pre_rd_sq + variance_est do
				:math.log(:math.pow(delta, 2) - player_pre_rd_sq - variance_est)
			else
				alpha - k * sys_const
			end

			{initial_a, initial_b}
	end

	defp iterative_algorithm_body(alpha, delta, player_pre_rd_sq, variance_est, sys_const, conv_tol, a, b, fa, fb) do
		if abs(b - a) > conv_tol do
			c = a + (a - b) * fa / (fb - fa)
			fc = calc_f(alpha, delta, player_pre_rd_sq, variance_est, sys_const, c)
			{a, fa} =
				if fc * fb < 0 do
					{b, fb}
				else
					{a, fa / 2}
				end
			iterative_algorithm_body(alpha, delta, player_pre_rd_sq, variance_est, sys_const, conv_tol, a, c, fa, fc)
		else
			a
		end
	end

	defp calc_k(alpha, delta, player_pre_rd_sq, variance_est, sys_const, k) do
		if calc_f(alpha, delta, player_pre_rd_sq, variance_est, sys_const, alpha - k * sys_const) < 0 do
			calc_k(alpha, delta, player_pre_rd_sq, variance_est, sys_const, k + 1)
		else
			k
		end
	end

	# g function
	defp calc_g(rd) do
		1 / :math.sqrt(1 + 3 * :math.pow(rd, 2) / :math.pow(:math.pi, 2))
	end

	# E function
	defp calc_e(player_pre_r, opponent_r, opponent_rd_g) do
		1 / (1 + :math.exp(-1 * opponent_rd_g * (player_pre_r - opponent_r)))
	end
end
