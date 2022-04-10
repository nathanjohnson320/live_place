defmodule LivePlace.Repo.Migrations.CreateGrids do
  use Ecto.Migration

  def change do
    create table(:grids, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :pixels, :binary
      add :place_id, references(:places, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:grids, [:place_id])
  end
end
