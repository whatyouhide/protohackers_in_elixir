import Config

log_level =
  cond do
    level = System.get_env("LOG_LEVEL") -> String.to_existing_atom(level)
    config_env() == :test -> :warn
    true -> :info
  end

config :logger, level: log_level

config :logger, :console, metadata: [:module]
