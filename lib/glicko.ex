defmodule Glicko do

	alias __MODULE__.{
		Player,
		GameResult,
	}

	@default_system_constant 0.8
	@default_convergence_tolerance 1.0e-7

	@type new_rating_opts_t :: [system_constant: float, convergence_tolerance: float]

	@doc """
	Generate a new Rating from an existing rating and a series of results.
	"""
	@spec new_rating(player :: Player.t, results :: list(GameResult.t), opts :: new_rating_opts_t) :: Player.t
	def new_rating(player, results, opts \\ [])
	def new_rating(player = %Player{version: :v1}, results, opts) do
		player
		|> Player.to_v2
		|> do_new_rating(results, opts)
		|> Player.to_v1
	end

	def new_rating(player = %Player{version: :v2}, results, opts) do
		do_new_rating(player, results, opts)
	end

	defp do_new_rating(player = %Player{version: :v2}, results, opts) do
		results = Enum.map(results, fn result ->
			result =
				Map.new
				|> Map.put(:opponent, Player.to_v2(result.opponent))
				|> Map.put(:score, result.score)

			result = Map.put(result, :opponent_rating_deviation_g, calc_g(result.opponent.rating_deviation))
			result = Map.put(result, :e, calc_e(player, result))
			result
		end)

		ctx =
			Map.new
			|> Map.put(:system_constant, Keyword.get(opts, :system_constant, @default_system_constant))
			|> Map.put(:convergence_tolerance, Keyword.get(opts, :convergence_tolerance, @default_convergence_tolerance))
			|> Map.put(:results, results)
			|> Map.put(:player, player)
			|> Map.put(:player_rating_deviation_squared, :math.pow(player.rating_deviation, 2))

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
		ctx = Map.put(ctx, :prerating_period, calc_prerating_period(ctx))
		# Step 7
		ctx = Map.put(ctx, :new_player_rating_deviation, calc_new_player_rating_deviation(ctx))
		ctx = Map.put(ctx, :new_player_rating, calc_new_player_rating(ctx))

		Player.new_v2([
			rating: ctx.new_player_rating,
			rating_deviation: ctx.new_player_rating_deviation,
			volatility: ctx.new_player_volatility,
		])
	end

	# Calculation of the estimated variance of the player's rating based on game outcomes
	defp calc_variance_estimate(%{results: results}) do
		results
		|> Enum.reduce(0.0, fn result, acc ->
			acc + :math.pow(result.opponent_rating_deviation_g, 2) * result.e * (1 - result.e)
		end)
		|> :math.pow(-1)
	end

	defp calc_delta(ctx) do
		calc_results_effect(ctx) * ctx.variance_estimate
	end

	defp calc_f(ctx, x) do
		:math.exp(x) *
		(:math.pow(ctx.delta, 2) - :math.exp(x) - ctx.player_rating_deviation_squared - ctx.variance_estimate) /
		(2 * :math.pow(ctx.player_rating_deviation_squared + ctx.variance_estimate + :math.exp(x), 2)) -
		(x - ctx.alpha) / :math.pow(ctx.system_constant, 2)
	end

	defp calc_alpha(%{player: player}) do
		:math.log(:math.pow(player.volatility, 2))
	end

	defp calc_new_player_volatility(%{a: a}) do
		:math.exp(a / 2)
	end

	defp calc_results_effect(%{results: results}) do
		Enum.reduce(results, 0.0, fn result, acc ->
			acc + result.opponent_rating_deviation_g * (result.score - result.e)
		end)
	end

	defp calc_new_player_rating(ctx) do
		ctx.player.rating + :math.pow(ctx.new_player_rating_deviation, 2) * calc_results_effect(ctx)
	end

	defp calc_new_player_rating_deviation(ctx) do
		1 / :math.sqrt(1 / :math.pow(ctx.prerating_period, 2) + 1 / ctx.variance_estimate)
	end

	defp calc_prerating_period(ctx) do
		:math.sqrt((:math.pow(ctx.new_player_volatility, 2) + ctx.player_rating_deviation_squared))
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
		if calc_f(ctx, (ctx.alpha - k * ctx.system_constant)) < 0 do
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
	defp calc_e(player, result) do
		1 / (1 + :math.exp(-1 * result.opponent_rating_deviation_g * (player.rating - result.opponent.rating)))
	end
end
