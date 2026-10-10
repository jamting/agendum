defmodule Agenda.MixProject do
  use Mix.Project

  def project do
    [
      app: :agenda,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      escript: [main_module: Agenda.CLI, name: "agenda"],
      aliases: aliases(),
      deps: deps()
    ]
  end

  def cli do
    [preferred_envs: [check: :test]]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      # code checks (dev/test only; never part of the program)
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # `mix check` is the single quality gate (used by humans, CI and AI agents).
  defp aliases do
    [
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors --force",
        "credo",
        "dialyzer",
        "test --warnings-as-errors"
      ]
    ]
  end
end
