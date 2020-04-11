defmodule Immutable.Repo do
  use Ecto.Repo,
    otp_app: :immutable,
    adapter: Ecto.Adapters.Postgres

  import Ecto.Query

  alias Immutable.Replicas.Replica
  # Add documentation
  # Add a Multi version
  # Add a Queued version

  # Compilation complains about opts here, please resolve

  # def edit(changeset, opts) do
  #   # need id back
  #   changeset
  #   |> update(opts)
  #   |> replicate()
  # end
  #
  def edit(changeset) do
    changeset
    |> update()
    |> replicate()
  end

  def edit_diff(changeset) do
    changeset
    |> update()
    |> case do
      {:ok, %{id: id}} = success ->
        Task.start(fn ->
          changeset.changes
          |> Map.put(:id, id)
          |> Replica.changeset()
          |> insert()
        end)

        success

      error ->
        error
    end
  end

  def create(changeset, opts \\ []) do
    changeset
    |> insert(opts)
    |> replicate()
  end

  def destroy(changeset, opts \\ []) do
    changeset
    |> delete(opts)
    |> replicate()
  end

  defp replicate({:error, _} = error) do
    error
  end

  # Will want to think about queuing here
  defp replicate({:ok, data} = success) do
    Task.start(fn ->
      data
      |> Replica.changeset()
      |> insert()
    end)

    success
  end

  defp replicate(data) do
    Task.start(fn ->
      data
      |> Replica.changeset()
      |> insert()
    end)

    data
  end

  def previous(schema, id) do
    from(Replica,
      where: [original_id: ^id],
      order_by: [desc: :id],
      limit: 2
    )
    |> all()
    |> case do
      # none found
      [] ->
        nil

      # no previous version
      [_ | []] ->
        nil

      [_latest, previous] ->
        previous.original_data
        |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
        |> Map.put(:id, id)
        |> (&struct!(schema, &1)).()
    end
  end

  def previous_diff(schema, id) do
    from(Replica,
      where: [original_id: ^id],
      order_by: [desc: :id],
      select: [:id, :original_id, :original_data]
    )
    |> all()
    |> case do
      # none found
      [] ->
        nil

      # no previous version
      [_ | []] ->
        nil

      [_latest | replicas] ->
        replicas
        |> Enum.reverse()
        |> Enum.reduce(%{}, fn curr, acc ->
          Map.merge(acc, curr.original_data)
        end)
        |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
        |> Map.put(:id, id)
        |> (&struct!(schema, &1)).()
    end
  end

  def latest(schema, id, datetime) do
    from(r in Replica,
      where: [original_id: ^id],
      where: r.inserted_at < datetime_add(^datetime, -1, "microsecond"),
      order_by: [desc: :id],
      select: [:id, :original_id, :original_data]
    )
    |> all()
    |> case do
      # none found
      [] ->
        nil

      # no previous version
      [_ | []] ->
        nil

      [_latest | replicas] ->
        replicas
        |> Enum.reverse()
        |> Enum.reduce(%{}, fn curr, acc ->
          Map.merge(acc, curr.original_data)
        end)
        |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
        |> Map.put(:id, id)
        |> (&struct!(schema, &1)).()
    end
  end
end

# we'll want to think about if we revive it in an schema/struct shape or just a plain map
# we'll want to make sure it's created in order!!!
# think about how to treat deletes
