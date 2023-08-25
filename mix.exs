defmodule SchemaGenerator.MixProject do
  use Mix.Project

  def project do
    [
      app: :schema_generator,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.10", optional: true, only: [:test]},
      {:inflex, "~> 2.0", only: [:test, :dev]},
      {:sourceror, "~> 0.13", only: [:test, :dev]}
    ]
  end
end
