defmodule Immutable.Replicas.Replica do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  schema "replicas" do
    field :original_id, :integer
    field :original_data, :map, default: %{}
    timestamps()
  end

  def changeset(%_{} = original) do
    {id, rest} =
      original
      |> Map.from_struct()
      |> Map.pop!(:id)

    change(%__MODULE__{}, %{original_id: id, original_data: Map.delete(rest, :__meta__)})
  end

  def changeset(changes) do
    {id, rest} = Map.pop!(changes, :id)

    change(%__MODULE__{}, %{original_id: id, original_data: Map.delete(rest, :__meta__)})
  end
end
