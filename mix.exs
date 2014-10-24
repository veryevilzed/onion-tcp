defmodule Onion.TCP.Mixfile do
  use Mix.Project

  def project do
    [app: :onion_tcp,
     version: "0.0.1",
     elixir: "~> 1.0.0",
     deps: deps]
  end

  def application do
    [applications: [:logger, :ranch, :onion],
     mod: {Onion.TCP.Application, []}]
  end

  defp deps do
    [
      {:onion, github: "veryevilzed/onion"},
      {:ranch, github: "ninenines/ranch", ref: "1.0.0"}
    ]
  end
end
