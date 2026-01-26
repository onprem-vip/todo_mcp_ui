defmodule TodoMcpUi.Todos.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :session_id, :string
    field :text, :string
    field :priority, Ecto.Enum, values: [:low, :medium, :high], default: :medium
    field :completed, :boolean
    field :due_date, :date
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:session_id, :text, :priority, :completed, :due_date, :notes])
    |> validate_required([:session_id, :text])
  end
end
