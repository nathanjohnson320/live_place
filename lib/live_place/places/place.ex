defmodule LivePlace.Places.Place do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivePlace.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "places" do
    field :name, :string
    field :size, :integer, default: 2
    field :active, :boolean, default: true

    belongs_to :user, User
    has_one :grid, LivePlace.Places.Grid

    timestamps()
  end

  @doc false
  def changeset(place, attrs) do
    place
    |> cast(attrs, [:user_id, :size, :active, :name])
    |> validate_required([:user_id, :size, :active, :name])
    |> validate_number(:size, greater_than_or_equal_to: 2, less_than_or_equal_to: 2000)
  end
end
