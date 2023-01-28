import Config

log_level =
  if config_env() == :test do
    :warn
  else
    :info
  end

config :logger, level: log_level
config :logger, :console, metadata: [:module, :address, :session, :pid]
