defmodule Toon.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/kentaro/toon_ex"

  def project do
    [
      app: :toon,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_core_path: "priv/plts",
        plt_local_path: "priv/plts",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [
          :error_handling,
          :underspecs,
          :unmatched_returns,
          :unknown
        ]
      ],
      aliases: aliases()
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:nimble_parsec, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.2"},

      # Development dependencies
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:jason, "~> 1.4", only: [:dev, :test], runtime: false},

      # Test dependencies
      {:stream_data, "~> 1.0", only: :test},
      {:excoveralls, "~> 0.18", only: :test},

      # Code quality
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    TOON (Token-Oriented Object Notation) encoder and decoder for Elixir.
    A compact data format optimized for LLM token efficiency, achieving 30-60%
    token reduction compared to JSON while maintaining readability.
    """
  end

  defp package do
    [
      name: "toon",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "TypeScript Version" => "https://github.com/johannschopplich/toon"
      },
      maintainers: ["Kentaro Kuribayashi"]
    ]
  end

  defp docs do
    [
      main: "Toon",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        Encoding: [
          Toon.Encode,
          Toon.Encode.Primitives,
          Toon.Encode.Objects,
          Toon.Encode.Arrays,
          Toon.Encode.Strings,
          Toon.Encode.Writer,
          Toon.Encode.Options,
          Toon.Encoder
        ],
        Decoding: [
          Toon.Decode,
          Toon.Decode.Parser,
          Toon.Decode.Primitives,
          Toon.Decode.Objects,
          Toon.Decode.Arrays,
          Toon.Decode.Strings,
          Toon.Decode.Options
        ],
        "Shared Types": [
          Toon.Types,
          Toon.Constants,
          Toon.Utils
        ],
        Errors: [
          Toon.EncodeError,
          Toon.DecodeError
        ]
      ]
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end
end
