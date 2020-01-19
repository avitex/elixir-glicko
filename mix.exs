defmodule Glicko.Mixfile do
  use Mix.Project

  @description """
  Implementation of the Glicko rating system
  """

  def project,
    do: [
      app: :glicko,
      version: "0.6.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: @description
    ]

  defp deps,
    do: [
      {:inch_ex, "~> 0.5", only: :docs},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false}
    ]

  defp package,
    do: [
      name: :glicko,
      maintainers: ["James Dyson"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/avitex/elixir-glicko"}
    ]
end
