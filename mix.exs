defmodule ChangesetHelpers.MixProject do
  use Mix.Project

  @version "0.23.0"

  def project do
    [
      app: :changeset_helpers,
      elixir: "~> 1.10",
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      version: @version,
      package: package(),
      description: "Functions to help working with nested changesets and associations",

      # ExDoc
      name: "Changeset Helpers",
      source_url: "https://github.com/mathieuprog/changeset_helpers",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.11"},
      {:ecto_sql, "~> 3.11", only: :test},
      {:postgrex, "~> 0.19", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: [
        "ecto.create --quiet",
        "ecto.rollback --all",
        "ecto.migrate",
        "test"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["Apache-2.0"],
      maintainers: ["Mathieu Decaffmeyer"],
      links: %{"GitHub" => "https://github.com/mathieuprog/changeset_helpers"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end
end
