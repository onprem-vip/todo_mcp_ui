defmodule TodoMcpUiMCP.Runners.KeepAlive do
  use GenServer, restart: :permanent, shutdown: 5_000

  # keep alive for mcp
  def start_link(args) do
    IO.inspect(args)
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init([mcp: mcp, interval: interval]) do

    Process.send_after(__MODULE__, :alive, interval)

    {:ok, %{interval: interval, mcp: mcp}}
  end

  @impl true
  def handle_info(:alive, %{mcp: mcp, interval: interval} = state) do
    case mcp.ping() do
      :pong ->
        IO.puts("Server is responsive")

      {:error, reason} ->
        IO.puts("Connection error: #{inspect(reason)}")
    end
    Process.send_after(self(), :alive, interval)

    {:noreply, state}
  end


end
