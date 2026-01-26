defmodule TodoMcpUi.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add(:session_id, :string)
      add(:text, :string)
      add(:priority, :string)
      add(:completed, :boolean)
      add(:due_date, :date)
      add(:notes, :text)

      timestamps(type: :utc_datetime)
    end
  end
end
