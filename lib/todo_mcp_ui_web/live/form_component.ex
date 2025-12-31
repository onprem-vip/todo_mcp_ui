defmodule TodoMcpUiWeb.TaskLive.FormComponent do
  use TodoMcpUiWeb, :live_component

  alias TodoMcpUi.Todos

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Add / Edit Task</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="task-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >

        <.input field={@form[:text]} type="text" label="Task" />
        <.input field={@form[:due_date]} type="date" label="Due Date" />
        <.input field={@form[:priority]} type="select" label="Priority" options={["Low": "low", "Medium": "medium", "High": "high"]} />
        <.input field={@form[:notes]} type="textarea" label="Notes" />

        <actions>
        <.button phx-disable-with="Saving...">Save</.button>
        </actions>

      </.simple_form>
      <.tool mcp={@todo_mcp} name="close_update_task_form" />

      <.lvjsexec id="update_task_script" js_code={@code} />
    </div>
    """
  end

  @impl true
  def update(%{task: task} = assigns, socket) do

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Todos.change_task(task))
     end)
    }
  end

  @impl true
  def handle_event("validate", %{"task" => task_params}, socket) do
    changeset = Todos.change_task(socket.assigns.task, task_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"task" => task_params}, socket) do
    save_task(socket, socket.assigns.action, task_params)
  end

  defp save_task(socket, :edit, task_params) do
    case Todos.update_task(socket.assigns.task, task_params) do
      {:ok, task} ->
        # id = task_params["id"]
        notify_parent({:saved, task})

        {:noreply,
         socket
        #  |> put_flash(:info, "Task updated successfully")
        #  |> push_event("js-next-event", %{})
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket = socket
        #  |> push_event("js-next-event", %{})
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_task(socket, :new, task_params) do
    case Todos.create_task(task_params) do
      {:ok, task} ->
        # inc_id = task_params["inc_id"]
        notify_parent({:saved, task})

        {:noreply,
         socket
        #  |> put_flash(:info, "Task created successfully")
        #  |> push_event("js-next-event", %{})
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        # socket = socket
        #   |> push_event("js-next-event", %{})
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
