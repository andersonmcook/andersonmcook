defmodule Immutable.Repo.Migrations.Initial do
  use Ecto.Migration

  def change do
    create table(:things) do
      add :name, :string
      add :description, :string
      add :input, :jsonb, null: false, default: "{}"
      timestamps()
    end

    create table(:replicas) do
      add :original_id, :bigserial
      add :original_data, :jsonb, null: false, default: "{}"
      timestamps()
    end
  end
end
