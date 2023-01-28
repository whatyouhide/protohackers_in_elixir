defmodule Protohackers.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        protohackers: [
          applications: [protohackers_first_days: :permanent]
        ],
        speed_daemon: [
          applications: [speed_daemon: :permanent]
        ],
        line_reversal: [
          applications: [line_reversal: :permanent]
        ]
      ]
    ]
  end

  defp deps do
    []
  end
end
