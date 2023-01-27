import Config

case System.fetch_env("LOG_LEVEL") do
  {:ok, level} ->
    config :logger, level: String.to_existing_atom(level)

  :error ->
    :ok
end
