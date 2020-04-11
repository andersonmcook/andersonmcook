defmodule Immutable.Things.Thing do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  schema "things" do
    field :description, :string
    field :input, :map, default: %{}
    field :name, :string
    timestamps()
  end

  def changeset(%__MODULE__{} = t, params \\ %{}) do
    cast(t, params, ~w(description name input)a)
  end
end
