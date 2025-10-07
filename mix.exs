defmodule AetherAtprotoCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :aether_atproto,
      start_permanent: Mix.env() == :prod,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps(),
      package: [
        maintainers: [
          "Josh Chernoff <hello@fullstack.ing>"
        ],
        licenses: ["Apache-2.0"],
        links: %{"Gitea" => @scm_url},
        files: ~w(lib mix.exs README.md)
      ],
      # docs: docs(),
      homepage_url: "https://gitea.fullstack.ing/Aether/aether_atproto",
      description: """
      Aether AT Proto Core is common shared logic to implement the AT Protocol.
      """,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers()
    ]
  end

  def cli do
    [preferred_envs: [docs: :docs]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4", only: :test, runtime: false},
      {:joken, "~> 2.6"},
      {:jose, "~> 1.11"},
      {:cbor, "~> 1.0"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end
end
