defmodule TodoMcpUi.Todos do
  @moduledoc """
  The Todos context.
  """

  import Ecto.Query, warn: false
  alias TodoMcpUi.Repo

  alias TodoMcpUi.Todos.Task

  @doc """
  Returns the list of tasks by session_id and completed status.

  ## Examples

      iex> list_tasks(%{"session_id" => session_id, "completed" => completed})
      [%Task{}, ...]

  """
  def list_tasks(%{"session_id" => session_id, "completed" => completed}) do
    query = from t in Task,
      where: t.session_id == ^session_id and t.completed == ^completed
    Repo.all(query)
  end

  def list_tasks(%{"completed" => completed}) do
    query = from t in Task,
      where: t.completed == ^completed
    Repo.all(query)
  end

  def list_tasks(%{"session_id" => session_id}) do
    query = from t in Task,
      where: t.session_id == ^session_id
    Repo.all(query)
  end

  def list_tasks do
    Repo.all(Task)
  end

  @doc """
  Gets a single task.

  Raises `Ecto.NoResultsError` if the Task does not exist.

  ## Examples

      iex> get_task!(123)
      %Task{}

      iex> get_task!(456)
      ** (Ecto.NoResultsError)

  """
  def get_task!(id) do
    [session_id, id] = String.split(id, "_", trim: true)
    Repo.get_by!(Task, [session_id: session_id, id: id])
  end

  def get_last_task(session_id) do
    query = from t in Task,
      where: t.inserted_at in subquery(from t2 in Task, where: t2.session_id == ^session_id, select: max(t2.inserted_at))

    Repo.one(query)
  end

  def get_stats(session_id) do
    %{
      "totalTasks" => list_tasks(%{"session_id" => session_id}) |> length(),
      "completedTasks" => list_tasks(%{"session_id" => session_id, "completed" => true}) |> length(),
      "activeTasks" => list_tasks(%{"session_id" => session_id, "completed" => false}) |> length(),
      "lastUpdatedTask" => (if not is_nil(get_last_task(session_id)), do: get_last_task(session_id) |> Map.get(:updated_at)),
      "completionPercentage" => (if (list_tasks(%{"session_id" => session_id}) |> length()) != 0,
        do: (list_tasks(%{"session_id" => session_id, "completed" => true}) |> length()) / (list_tasks(%{"session_id" => session_id}) |> length()),
        else: 0
        )
    }
  end

  @doc """
  Creates a task.

  ## Examples

      iex> create_task(%{field: value})
      {:ok, %Task{}}

      iex> create_task(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_task(attrs) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a task.

  ## Examples

      iex> update_task(task, %{field: new_value})
      {:ok, %Task{}}

      iex> update_task(task, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a task.

  ## Examples

      iex> delete_task(task)
      {:ok, %Task{}}

      iex> delete_task(task)
      {:error, %Ecto.Changeset{}}

  """
  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.

  ## Examples

      iex> change_task(task)
      %Ecto.Changeset{data: %Task{}}

  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end
end
