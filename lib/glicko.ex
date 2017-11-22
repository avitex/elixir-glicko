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

	defp do_new_rating({player_rating, player_rating_deviation, player_volatility}, [], _) do
		player_post_rating_deviation = calc_player_pre_rating_deviation(
			:math.pow(player_rating_deviation, 2),
			player_volatility
		)

		{player_rating, player_post_rating_deviation, player_volatility}
	end
	defp do_new_rating({player_rating, player_rating_deviation, player_volatility}, results, opts) do
		ctx =
			Map.new
			|> Map.put(:system_constant, Keyword.get(opts, :system_constant, @default_system_constant))
			|> Map.put(:convergence_tolerance, Keyword.get(opts, :convergence_tolerance, @default_convergence_tolerance))
			|> Map.put(:player_rating, player_rating)
			|> Map.put(:player_volatility, player_volatility)
			|> Map.put(:player_rating_deviation, player_rating_deviation)
			|> Map.put(:player_rating_deviation_squared, :math.pow(player_rating_deviation, 2))

		# Init
		ctx = Map.put(ctx, :results, Enum.map(results, &build_internal_result(ctx, &1)))
		ctx = Map.put(ctx, :results_effect, calc_results_effect(ctx))
		# Step 3
		ctx = Map.put(ctx, :variance_estimate, calc_variance_estimate(ctx))
		# Step 4
		ctx = Map.put(ctx, :delta, calc_delta(ctx))
		# Step 5.1
		ctx = Map.put(ctx, :alpha, calc_alpha(ctx))
		# Step 5.2
		{initial_a, initial_b} = iterative_algorithm_initial(ctx)
		ctx = Map.put(ctx, :initial_a, initial_a)
		ctx = Map.put(ctx, :initial_b, initial_b)
		# Step 5.3
		ctx = Map.put(ctx, :initial_fa, calc_f(ctx, ctx.initial_a))
		ctx = Map.put(ctx, :initial_fb, calc_f(ctx, ctx.initial_b))
		# Step 5.4
		ctx = Map.put(ctx, :a, iterative_algorithm_body(
			ctx, ctx.initial_a, ctx.initial_b, ctx.initial_fa, ctx.initial_fb
		))
		# Step 5.5
		ctx = Map.put(ctx, :new_player_volatility, calc_new_player_volatility(ctx))
		# Step 6
		ctx = Map.put(ctx, :player_pre_rating_deviation, calc_player_pre_rating_deviation(
			ctx.player_rating_deviation_squared, ctx.new_player_volatility
		))
		# Step 7
		ctx = Map.put(ctx, :new_player_rating_deviation, calc_new_player_rating_deviation(ctx))
		ctx = Map.put(ctx, :new_player_rating, calc_new_player_rating(ctx))

		{ctx.new_player_rating, ctx.new_player_rating_deviation, ctx.new_player_volatility}
	end

	defp build_internal_result(ctx, result) do
		result =
			Map.new
			|> Map.put(:score, Result.score(result))
			|> Map.put(:opponent_rating, Result.opponent_rating(result))
			|> Map.put(:opponent_rating_deviation, Result.opponent_rating_deviation(result))
			|> Map.put(:opponent_rating_deviation_g, calc_g(Result.opponent_rating_deviation(result)))

		Map.put(result, :e, calc_e(ctx.player_rating, result))
	end

	# Calculation of the estimated variance of the player's rating based on game outcomes
	defp calc_variance_estimate(ctx) do
		ctx.results
		|> Enum.reduce(0.0, fn result, acc ->
			acc + :math.pow(result.opponent_rating_deviation_g, 2) * result.e * (1 - result.e)
		end)
		|> :math.pow(-1)
	end

	defp calc_delta(ctx) do
		ctx.results_effect * ctx.variance_estimate
	end

	defp calc_f(ctx, x) do
		:math.exp(x) *
		(:math.pow(ctx.delta, 2) - :math.exp(x) - ctx.player_rating_deviation_squared - ctx.variance_estimate) /
		(2 * :math.pow(ctx.player_rating_deviation_squared + ctx.variance_estimate + :math.exp(x), 2)) -
		(x - ctx.alpha) / :math.pow(ctx.system_constant, 2)
	end

	defp calc_alpha(ctx) do
		:math.log(:math.pow(ctx.player_volatility, 2))
	end

	defp calc_new_player_volatility(%{a: a}) do
		:math.exp(a / 2)
	end

	defp calc_results_effect(ctx) do
		Enum.reduce(ctx.results, 0.0, fn result, acc ->
			acc + result.opponent_rating_deviation_g * (result.score - result.e)
		end)
	end

	defp calc_new_player_rating(ctx) do
		ctx.player_rating + :math.pow(ctx.new_player_rating_deviation, 2) * ctx.results_effect
	end

	defp calc_new_player_rating_deviation(ctx) do
		1 / :math.sqrt(1 / :math.pow(ctx.player_pre_rating_deviation, 2) + 1 / ctx.variance_estimate)
	end

	defp calc_player_pre_rating_deviation(player_rating_deviation_squared, player_volatility) do
		:math.sqrt((:math.pow(player_volatility, 2) + player_rating_deviation_squared))
	end

	defp iterative_algorithm_initial(ctx) do
		initial_a = ctx.alpha
		initial_b =
			if :math.pow(ctx.delta, 2) > ctx.player_rating_deviation_squared + ctx.variance_estimate do
				:math.log(:math.pow(ctx.delta, 2) - ctx.player_rating_deviation_squared - ctx.variance_estimate)
			else
				ctx.alpha - calc_k(ctx, 1) * ctx.system_constant
			end

			{initial_a, initial_b}
	end

	defp iterative_algorithm_body(ctx, a, b, fa, fb) do
		if abs(b - a) > ctx.convergence_tolerance do
			c = a + (a - b) * fa / (fb - fa)
			fc = calc_f(ctx, c)
			{a, fa} =
				if fc * fb < 0 do
					{b, fb}
				else
					{a, fa / 2}
				end
			iterative_algorithm_body(ctx, a, c, fa, fc)
		else
			a
		end
	end

	defp calc_k(ctx, k) do
		if calc_f(ctx, ctx.alpha - k * ctx.system_constant) < 0 do
			calc_k(ctx, k + 1)
		else
			k
		end
	end

	# g function
	defp calc_g(rating_deviation) do
		1 / :math.sqrt(1 + 3 * :math.pow(rating_deviation, 2) / :math.pow(:math.pi, 2))
	end

	# E function
	defp calc_e(player_rating, result) do
		1 / (1 + :math.exp(-1 * result.opponent_rating_deviation_g * (player_rating - result.opponent_rating)))
	end
end
