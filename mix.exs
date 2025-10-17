defmodule AetherAtprotoCore.MixProject do
  use Mix.Project
  @version "0.1.4"
  def project do
    [
      app: :aether_atproto,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Aether ATProto",
      description:
        "Aether ATProto is a set of common & shared logic to implement the AT Protocol",
      source_url: "https://github.com/AetherLib/aether_atproto",
      homepage_url: "https://aetherlib.org",
      docs: docs(),
      package: package(),
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
      {:req, "~> 0.5.15"},
      {:jason, "~> 1.4"},
      {:joken, "~> 2.6"},
      {:jose, "~> 1.11"},
      {:cbor, "~> 1.0"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Aether ATProto",
      source_ref: "v#{@version}",
      source_url: "https://github.com/AetherLib/aether_atproto",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules()
    ]
  end

  defp extras do
    [
      "README.md",
      "LICENSE.md": [title: "License"]
    ]
  end

  defp groups_for_extras do
    [
      Documentation: ~r/docs\//
    ]
  end

  defp groups_for_modules do
    [
      CAR: [
        Aether.ATProto.CAR,
        Aether.ATProto.CAR.Block
      ],
      Crypto: [
        Aether.ATProto.Crypto.DPoP,
        Aether.ATProto.Crypto.PKCE
      ],
      DID: [
        Aether.ATProto.DID,
        Aether.ATProto.DID.Document,
        Aether.ATProto.DID.Document.Client,
        Aether.ATProto.DID.Document.Service
      ],
      MST: [
        Aether.ATProto.MST,
        Aether.ATProto.MST.Entry
      ]
    ]
  end

  defp package do
    [
      maintainers: [
        "Josh Chernoff <hello@fullstack.ing>"
      ],
      name: "aether_atproto",
      homepage_url: "https://aetherlib.org",
      licenses: ["Apache-2.0"],
      links: %{
        "Hex Package" => "https://hex.pm/packages/aether_atproto",
        "GitHub" => "https://github.com/AetherLib/aether_atproto",
        "Gitea" => "https://gitea.fullstack.ing/Aether/aether_atproto",
        "ATProto Specification" => "https://atproto.com/specs/lexicon"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.md)
    ]
  end
end
