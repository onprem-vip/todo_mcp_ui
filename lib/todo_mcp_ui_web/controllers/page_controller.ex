defmodule TodoMcpUiWeb.PageController do
  use TodoMcpUiWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/tasks")
    # render(conn, :home)
  end
end
