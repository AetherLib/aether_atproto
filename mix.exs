defmodule AetherAtprotoCore.MixProject do
  use Mix.Project
  @version "0.1.0"
  @scm_url "https://gitea.fullstack.ing/Aether/aether_atproto_core"
  @elixir_requirement "~> 1.18"

  def project do
    [
      app: :aether_atproto_core,
      start_permanent: Mix.env() == :prod,
      version: @version,
      elixir: @elixir_requirement,
      deps: deps(),
      package: [
        maintainers: [
          "Josh Chernoff"
        ],
        licenses: ["Apache-2.0"],
        links: %{"Gitea" => @scm_url},
        files: ~w(lib mix.exs README.md)
      ],
      source_url: @scm_url,
      # docs: docs(),
      homepage_url: "https://gitea.fullstack.ing/FullStack.ing/aether",
      description: """
      Aether AT Proto Core is common shared logic for use in other libs that implement the AT Protocol.
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
