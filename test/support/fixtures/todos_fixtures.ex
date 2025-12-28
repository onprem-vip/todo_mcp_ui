defmodule TodoMcpUi.TodosFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TodoMcpUi.Todos` context.
  """

  @doc """
  Generate a task.
  """
  def task_fixture(attrs \\ %{}) do
    {:ok, task} =
      attrs
      |> Enum.into(%{

      })
      |> TodoMcpUi.Todos.create_task()

    task
  end

  @doc """
  Generate a task.
  """
  def task_fixture(attrs \\ %{}) do
    {:ok, task} =
      attrs
      |> Enum.into(%{
        text: "some text"
      })
      |> TodoMcpUi.Todos.create_task()

    task
  end
end
