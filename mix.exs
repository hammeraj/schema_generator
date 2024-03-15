defmodule SchemaGenerator.MixProject do
  use Mix.Project

  def project do
    [
      app: :schema_generator,
      version: "0.2.0",
      elixir: "~> 1.14",
      description: description(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.10", optional: true, only: [:test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:inflex, "~> 2.0"},
      {:sourceror, "~> 0.13"}
    ]
  end

  defp description do
    "Mix task to generate boilerplate query functions on Ecto Schema files"
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["BSD 3-Clause \"New\" or \"Revised\" License"],
      links: %{"GitHub" => "https://github.com/hammeraj/schema_generator"}
    ]
  end
end
