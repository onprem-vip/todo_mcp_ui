defmodule TodoMcpUi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TodoMcpUiWeb.Telemetry,
      TodoMcpUi.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:todo_mcp_ui, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:todo_mcp_ui, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TodoMcpUi.PubSub},
      # Start a worker by calling: TodoMcpUi.Worker.start_link(arg)
      # {TodoMcpUi.Worker, arg},
      # Start to serve requests, typically the last entry
      {TodoMcpUiMCP.Clients.TodoAppMCP,
          transport:
            {:streamable_http,
             base_url:
               Application.get_env(:todo_mcp_ui, TodoMcpUiMCP.Clients.TodoAppMCP)[:base_url]}},
      {TodoMcpUiMCP.Runners.KeepAlive, [mcp: TodoMcpUiMCP.Clients.TodoAppMCP, interval: 15_000]},
      TodoMcpUiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TodoMcpUi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TodoMcpUiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
