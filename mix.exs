defmodule Glicko.Mixfile do
	use Mix.Project

	def project, do: [
		app: :glicko,
		version: "0.1.0",
		elixir: "~> 1.5",
		start_permanent: Mix.env == :prod,
		deps: deps(),
	]

	def application, do: [
		extra_applications: [:logger],
	]

	defp deps, do: [
		{:ex_doc, "~> 0.16", only: :dev, runtime: false},
		{:credo, "~> 0.8", only: [:dev, :test], runtime: false},
	]
end
