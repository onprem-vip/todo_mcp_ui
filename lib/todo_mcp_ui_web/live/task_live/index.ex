defmodule TodoMcpUiWeb.TaskLive.Index do
  use TodoMcpUiWeb, :live_view

  alias TodoMcpUi.Todos
  alias TodoMcpUi.Todos.Task
  alias ExVoix.ModelContext.Tool

  @impl true
  def mount(params, session, socket) do
    IO.inspect({"mount", params, session})

    if connected?(socket) do

    end

    socket =
      case Map.get(session, "_csrf_token") do
        nil ->
          :ok =
            :secret_key_base
            |> socket.endpoint.config
            |> Plug.CSRFProtection.load_state(nil)

          token = Plug.CSRFProtection.dump_state()
          session = Map.put(session, "_csrf_token", token)

          {:ok, socket} = mount(params, session, socket)
          socket

        session_state ->
          connect_params = Phoenix.LiveView.get_connect_params(socket) || %{}
          csrf_token = Map.get(connect_params, "_csrf_token")
          loading? = is_nil(csrf_token)

          valid_token? =
            Plug.CSRFProtection.valid_state_and_csrf_token?(
              session_state,
              csrf_token
            )

          state =
            case {loading?, valid_token?} do
              {true, false} -> :loading
              {false, true} -> :complete
              _csrf_attack -> :error
            end

          socket
          |> assign(mount: state)
          |> assign(sess_id: session["_csrf_token"])
      end

    tasks =
      Todos.list_tasks(%{"session_id" => socket.assigns.sess_id})
      # |> Enum.with_index()
      |> Enum.map(fn t -> %{id: t.id, task: t} end)

    {
      :ok,
      socket
      |> assign(:add_task_text, nil)
      |> assign(:stats, stats(socket.assigns.sess_id))
      |> assign(:current_date, current_date())
      |> assign(:resource, nil)
      |> assign(:todo_mcp, TodoMcpUiMCP.Clients.TodoAppMCP)
      |> stream(:tasks, tasks)
    }
  end

  @impl true
  def handle_params(params, url, socket) do
    # IO.inspect({"handle_params", params, (if Map.has_key?(socket.assigns, :questions), do: socket.assigns.questions, else: nil)})
    # IO.inspect(URI.parse(url))
    socket =
      socket
      |> assign(uri: URI.parse(url))

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :stats, _params) do
    task_changeset = task_changeset_from(%{})

    socket
    |> assign(:page_title, "Todo App · Stats")
    |> assign(:task, %Task{})
    |> assign(:form, to_form(task_changeset))
    |> execute_remote_code("#remote-code-renderer", socket.assigns.resource)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    task = Todos.get_task!(id)
    task_changeset = task_changeset_from(task, %{})

    socket
    |> assign(:page_title, "Todo App · Edit Task")
    |> assign(:task, task)
    |> assign(:form, to_form(task_changeset))
  end

  defp apply_action(socket, :new, _params) do
    task_changeset = task_changeset_from(%{})

    socket
    |> assign(:page_title, "Todo App · New Task")
    |> assign(:task, %Task{})
    |> assign(:form, to_form(task_changeset))
  end

  defp apply_action(socket, :index, params) do
    task_changeset = task_changeset_from(params)
    IO.inspect(task_changeset, label: "Task from params")

    socket
    |> assign(:page_title, "Todo App · Tasks")
    |> assign(:task, %Task{})
    |> assign(:form, to_form(task_changeset))
  end

  @impl true
  def handle_info({TodoMcpUiWeb.TaskLive.FormComponent, {:saved, task}}, socket) do
    tsk = %{id: task.id, task: task}
    {:noreply, stream_insert(socket, :tasks, tsk)}
  end

  @impl true
  def handle_event("add_task", %{"task" => %{"text" => text}}, socket) do
    IO.inspect(text, label: "add_task text")
    if not is_nil(text) and text != "" do
      socket =
        socket |> assign(:add_task_text, text)

      today = DateTime.utc_now()
      today_date = DateTime.to_date(today)
      due_date = Date.shift(today_date, week: 1)

      {:ok, task} = Todos.create_task(%{"session_id" => socket.assigns.sess_id, "completed" => false, "text" => text, "priority" => "medium", "due_date" => due_date, "notes" => ""})
      tsk = %{id: task.id, task: task}
      {:noreply,
        socket
          |> assign(:stats, stats(socket.assigns.sess_id))
          |> assign(:current_date, current_date())
          |> assign(:add_task_text, nil)
          |> stream_insert(:tasks, tsk)}
    else
      {:noreply,
        socket
          |> assign(:stats, stats(socket.assigns.sess_id))
          |> assign(:current_date, current_date())
      }
    end
  end

  @impl true
  def handle_event("update_task", %{"task" => task}, socket) do
    #IO.inspect(task, label: "update_task")
    updated_tasks =
      Enum.map(task, fn {"completed_" <> id, value} ->
        task = Todos.get_task!(id)
        {:ok, tsk} = Todos.update_task(task, %{"completed" => value})
        %{id: tsk.id, task: tsk}
      end)
    task = Enum.at(updated_tasks, 0)

    {:noreply,
      socket
        |> assign(:stats, stats(socket.assigns.sess_id))
        |> assign(:current_date, current_date())
        |> stream_insert(:tasks, task)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    task = Todos.get_task!(id)
    {:ok, _} = Todos.delete_task(task)
    tsk = %{id: task.id, task: task}

    {:noreply,
      socket
        |> assign(:stats, stats(socket.assigns.sess_id))
        |> assign(:current_date, current_date())
        |> stream_delete(:tasks, tsk)}
  end

  @impl true
  def handle_event("call", params, socket) do
    # IO.inspect(params, label: "params in call event")

    case Tool.call(params) do
      nil ->
        {:noreply, socket}

      {:ok, res} ->
        IO.inspect(res, label: "call result")
        {:noreply, tool_call_action(socket, res)}

    end
  end

  defp tool_call_action(socket, res) do
    if is_map(res) and not Map.get(res, "isError", true) do
      case Map.get(res, "tool") do
        "add_task" ->
          socket
            |> assign(:stats, stats(socket.assigns.sess_id))
            |> assign(:current_date, current_date())
            |> stream_insert(:tasks, maybe_extract_item(res))

        "complete_task" ->
          socket
            |> assign(:stats, stats(socket.assigns.sess_id))
            |> assign(:current_date, current_date())
            |> stream_insert(:tasks, maybe_extract_item(res))

        "remove_task" ->
          socket
            |> assign(:stats, stats(socket.assigns.sess_id))
            |> assign(:current_date, current_date())
            |> stream_delete(:tasks, maybe_extract_item(res))

        "show_stats_window" ->
          socket
            |> assign(:resource, res)
            |> push_patch(to: "/tasks/stats")

        _ ->
          socket |> execute_remote_code("#executable-script", res)

      end
    else
      tasks =
        Todos.list_tasks(%{"session_id" => socket.assigns.sess_id})
        |> Enum.map(fn t -> %{id: t.id, task: t} end)

      socket
        |> assign(:stats, stats(socket.assigns.sess_id))
        |> assign(:current_date, current_date())
        |> stream(:tasks, tasks, reset: true)
    end
  end

  defp maybe_extract_item(res) do
    item = Map.get(res, "item") |> :json.decode()
    task =
      try do
        Todos.get_task!(Map.get(item, "id"))
      rescue
        _ -> item
      end
    %{id: (if is_nil(Map.get(task, "id")), do: task.id, else: Map.get(task, "id")), task: task}
  end

  defp execute_remote_code(socket, dom_id, res) do
    payload = %{to: dom_id, resource: res}
    socket
      |> assign(:resource, res)
      |> push_event("ui-resource-render", payload)
  end

  defp task_changeset_from(task = %Task{}, params) do
    Todos.change_task(task, params)
  end
  defp task_changeset_from(params = %{}) do
    Todos.change_task(%Task{}, params)
  end
  defp task_changeset_from(_), do: nil

  defp priority_badge(priority, completed) do
    case priority do
      :high ->
        if completed,
          do: "text-xs uppercase font-semibold opacity-30 badge badge-error",
          else: "text-xs uppercase font-semibold opacity-60 badge badge-error"
      :medium ->
        if completed,
          do: "text-xs uppercase font-semibold opacity-30 badge badge-warning",
          else: "text-xs uppercase font-semibold opacity-60 badge badge-warning"
      :low ->
        if completed,
          do: "text-xs uppercase font-semibold opacity-30 badge badge-info",
          else: "text-xs uppercase font-semibold opacity-60 badge badge-info"
    end
  end

  defp complete_task_text(completed) do
    if completed, do: "line-through", else: ""
  end

  defp due_date_in_days(due_date) do
    today = DateTime.utc_now()
    date_today = DateTime.to_date(today)

    diff = Date.diff(date_today, due_date)
    cond do
      diff < 0 -> "Due: #{diff*(-1)} more days"
      diff > 0 -> "Due: #{diff} days ago"
      diff == 0 -> "Due: today"
    end
  end

  defp due_date_text(completed) do
    if completed,
      do: "text-xs uppercase font-semibold opacity-30 badge badge-outline badge-secondary",
      else: "text-xs uppercase font-semibold opacity-60 badge badge-outline badge-secondary"
  end

  defp notes_tooltip(notes) do
    if not is_nil(notes) and notes != "", do: "tooltip hover:tooltip-open tooltip-right tooltip-secondary", else: "hidden"
  end

  defp stats(session_id) do
    Todos.get_stats(session_id) |> Jason.encode!()
  end

  defp current_date() do
    today = DateTime.utc_now()
    today_date = DateTime.to_date(today)
    Date.to_string(today_date)
  end

end
