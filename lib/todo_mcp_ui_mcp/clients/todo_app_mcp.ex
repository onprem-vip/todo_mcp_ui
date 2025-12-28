defmodule TodoMcpUiMCP.Clients.TodoAppMCP do
  use Anubis.Client,
    name: "TodoAppMCP",
    version: "1.0.0",
    protocol_version: "2025-03-26",
    capabilities: [:roots, :sampling]
end
