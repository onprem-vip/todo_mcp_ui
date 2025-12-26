defmodule TodoMcpUi.Repo do
  use Ecto.Repo,
    otp_app: :todo_mcp_ui,
    adapter: Ecto.Adapters.SQLite3
end
