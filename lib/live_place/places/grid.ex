defmodule LivePlace.Places.Grid do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "grids" do
    field :pixels, Serialize
    field :place_id, :binary_id

    timestamps()
  end

  @doc false
  def changeset(grid, attrs) do
    grid
    |> cast(attrs, [:pixels])
    |> validate_required([:pixels])
  end
end
