defmodule Protohackers.BudgetChatServer do
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  defstruct [:listen_socket, :supervisor, :ets]

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    ets = :ets.new(__MODULE__, [:public])

    listen_options = [
      ifaddr: {0, 0, 0, 0},
      mode: :binary,
      active: false,
      reuseaddr: true,
      exit_on_close: false,
      packet: :line,
      buffer: 1024 * 100
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Started server on port #{port}")
        state = %__MODULE__{listen_socket: listen_socket, supervisor: supervisor, ets: ets}
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(state.supervisor, fn ->
          handle_connection(socket, state.ets)
        end)

        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  ## Helpers

  defp handle_connection(socket, ets) do
    :ok = :gen_tcp.send(socket, "What's your username?\n")

    case :gen_tcp.recv(socket, 0, 300_000) do
      {:ok, line} ->
        username = String.trim(line)

        if username =~ ~r/^[[:alnum:]]+$/ do
          Logger.debug("Username #{username} connected")
          all_users = :ets.match(ets, :"$1")
          usernames = Enum.map_join(all_users, ", ", fn [{_socket, username}] -> username end)
          :ets.insert(ets, {socket, username})

          Enum.each(all_users, fn [{socket, _username}] ->
            :gen_tcp.send(socket, "* #{username} has entered the chat\n")
          end)

          :ok = :gen_tcp.send(socket, "* The room contains: #{usernames}\n")
          handle_chat_session(socket, ets, username)
        else
          :ok = :gen_tcp.send(socket, "Invalid username\n")
          :gen_tcp.close(socket)
        end

      {:error, _reason} ->
        :gen_tcp.close(socket)
        :ok
    end
  end

  def handle_chat_session(socket, ets, username) do
    case :gen_tcp.recv(socket, 0, 300_000) do
      {:ok, message} ->
        message = String.trim(message)

        if message != "" do
          all_sockets = :ets.match(ets, {:"$1", :_})

          for [other_socket] <- all_sockets, other_socket != socket do
            :gen_tcp.send(other_socket, "[#{username}] #{message}\n")
          end
        end

        handle_chat_session(socket, ets, username)

      {:error, _reason} ->
        all_sockets = :ets.match(ets, {:"$1", :_})

        for [other_socket] <- all_sockets, other_socket != socket do
          :gen_tcp.send(other_socket, "* #{username} left\n")
        end

        _ = :gen_tcp.close(socket)
        :ets.delete(ets, socket)
    end
  end
end
