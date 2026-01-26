defmodule TodoMcpUiWeb.TaskController do
  use TodoMcpUiWeb, :controller

  alias TodoMcpUi.Todos
  alias TodoMcpUi.Todos.Task

  action_fallback TodoMcpUiWeb.FallbackController

  def index(conn, _params) do
    session_id = get_session(conn, :session_id) || Plug.CSRFProtection.get_csrf_token()
    tasks = Todos.list_tasks(%{"session_id" => session_id})
    render(conn, :index, tasks: tasks)
  end

  def create(conn, %{"task" => task_params}) do
    with {:ok, %Task{} = task} <- Todos.create_task(task_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/tasks/#{task}")
      |> render(:show, task: task)
    end
  end

  def show(conn, %{"id" => id}) do
    task = Todos.get_task!(id)
    render(conn, :show, task: task)
  end

  def update(conn, %{"id" => id, "task" => task_params}) do
    task = Todos.get_task!(id)

    with {:ok, %Task{} = task} <- Todos.update_task(task, task_params) do
      render(conn, :show, task: task)
    end
  end

  def delete(conn, %{"id" => id}) do
    task = Todos.get_task!(id)

    with {:ok, %Task{}} <- Todos.delete_task(task) do
      send_resp(conn, :no_content, "")
    end
  end

  def show_stats(conn, _params = %{"session_id" => session_id}) do
    stats = Todos.get_stats(session_id)
    json(conn, stats)
  end
end
