defmodule ImmutableTest do
  use Immutable.DataCase, async: true

  alias Immutable.{
    Repo,
    Things.Thing
  }

  @tag :skip
  test "no previous" do
  end

  @tag :skip
  test "no match" do
  end

  @tag :skip
  test "full replication fails if full data is not used in changeset" do
    # Insert
    {:ok, %{id: id}} =
      %Thing{}
      |> Thing.changeset(%{
        description: "original",
        input: %{"a" => 1, "b" => %{"c" => "d"}},
        name: "whaddup"
      })
      |> Repo.create()

    # Edit
    {:ok, _} =
      from(Thing, select: [:id])
      |> Repo.get!(id)
      |> Thing.changeset(%{input: %{"completely" => "different"}})
      |> Repo.edit()

    # Edit again
    {:ok, _} =
      from(Thing, select: [:id])
      |> Repo.get!(id)
      |> Thing.changeset(%{})
      |> Repo.edit()

    Process.sleep(1_000)
    previous = Repo.previous(Thing, id)

    refute match?(
             %{
               id: ^id,
               description: "original",
               input: %{"completely" => "different"},
               name: "whaddup"
             },
             previous
           )
  end

  @tag :skip
  test "full replication requires full data" do
    # Insert
    {:ok, %{id: id}} =
      %Thing{}
      |> Thing.changeset(%{
        description: "original",
        input: %{"a" => 1, "b" => %{"c" => "d"}},
        name: "whaddup"
      })
      |> Repo.create()

    # Edit
    {:ok, _} =
      Thing
      |> Repo.get!(id)
      |> Thing.changeset(%{input: %{"completely" => "different"}})
      |> Repo.edit()

    # Edit again
    {:ok, _} =
      Thing
      |> Repo.get!(id)
      |> Thing.changeset(%{})
      |> Repo.edit()

    Process.sleep(1_000)
    previous = Repo.previous(Thing, id)

    assert match?(
             %{
               id: ^id,
               description: "original",
               input: %{"completely" => "different"},
               name: "whaddup"
             },
             previous
           )
  end

  @tag :skip
  test "replicates with diff, no full data required" do
    # Insert
    {:ok, %{id: id}} =
      %Thing{}
      |> Thing.changeset(%{
        description: "original",
        input: %{"a" => 1, "b" => %{"c" => "d"}},
        name: "whaddup"
      })
      |> Repo.create()

    # Edit
    {:ok, _} =
      from(Thing, select: [:id])
      |> Repo.get!(id)
      |> Thing.changeset(%{input: %{"completely" => "different"}})
      |> Repo.edit_diff()

    # Edit again
    {:ok, _} =
      from(Thing, select: [:id])
      |> Repo.get!(id)
      |> Thing.changeset(%{})
      |> Repo.edit_diff()

    Process.sleep(1_000)
    previous = Repo.previous_diff(Thing, id)

    assert match?(
             %{
               id: ^id,
               description: "original",
               input: %{"completely" => "different"},
               name: "whaddup"
             },
             previous
           )
  end

  # @tag :skip
  @tag timeout: :timer.minutes(2)
  test "large number no-diff" do
    Ecto.Adapters.SQL.query!(Repo, "SELECT pg_size_pretty(pg_total_relation_size('replicas'));")
    |> IO.inspect(label: "no-diff size")

    require Integer
    # Initial
    {:ok, result} =
      %Thing{}
      |> Thing.changeset(%{description: "old", input: %{"yo" => "hey"}, name: "old!"})
      |> Repo.create()

    IO.puts("starting the no-diff big boy")

    random = fn -> Enum.random(~w(a b c d e f g)) end

    Enum.each(1..20_000, fn n ->
      # Edit the original 20_000 times
      result
      |> Thing.changeset(%{
        name: random.(),
        description: random.(),
        input: Enum.random([%{random.() => random.()}])
      })
      |> Repo.edit()

      # This is just noise
      {:ok, t} =
        %Thing{}
        |> Thing.changeset(%{description: "noise", input: %{}, name: "who cares"})
        |> Repo.create()

      # Edit ever other one for more noise
      if Integer.is_even(n) do
        t
        |> Thing.changeset(%{name: "aaaaaaaaaaaaa"})
        |> Repo.edit()
      end
    end)

    # Controlled edits
    {:ok, _} =
      Thing
      |> Repo.get!(result.id)
      |> Thing.changeset(%{description: "previous"})
      |> Repo.edit()

    {:ok, _} =
      Thing
      |> Repo.get!(result.id)
      |> Thing.changeset(%{name: "new!"})
      |> Repo.edit()

    {:ok, _} =
      Thing
      |> Repo.get!(result.id)
      |> Thing.changeset(%{input: %{"yo" => "hey"}})
      |> Repo.edit()

    # One more
    {:ok, _} =
      Thing
      |> Repo.get!(result.id)
      |> Thing.changeset(%{
        description: "latest",
        input: %{"doesn't" => "matter"},
        name: "latest name"
      })
      |> Repo.edit()

    IO.puts("no-diff big boy over")
    Process.sleep(1_000)

    Ecto.Adapters.SQL.query!(Repo, "SELECT pg_size_pretty(pg_total_relation_size('replicas'));")
    |> IO.inspect(label: "no-diff size")

    # Get Latest
    start = System.monotonic_time(:millisecond)
    previous = Repo.previous(Thing, result.id)

    # IO.inspect(time / 1000, label: "time in milliseconds")
    time_elapsed = abs(start - System.monotonic_time(:millisecond))

    IO.puts("#{time_elapsed} ms")

    assert match?(%{description: "previous", input: %{"yo" => "hey"}, name: "new!"}, previous)
  end

  @tag :skip
  @tag timeout: :timer.minutes(2)
  test "large number with diff does not require full data" do
    Ecto.Adapters.SQL.query!(Repo, "SELECT pg_size_pretty(pg_total_relation_size('replicas'));")
    |> IO.inspect(label: "diff size")

    require Integer
    # Initial
    {:ok, %{id: id}} =
      %Thing{}
      |> Thing.changeset(%{description: "old", input: %{"yo" => "hey"}, name: "old!"})
      |> Repo.create()

    stale = Repo.get!(from(Thing, select: [:id]), id)
    IO.puts("starting the diff big boy")

    random = fn -> Enum.random(~w(a b c d e f g)) end

    Enum.each(1..20_000, fn n ->
      # Edit the original 20_000 times
      stale
      |> Thing.changeset(%{
        name: random.(),
        description: random.(),
        input: Enum.random([%{random.() => random.()}])
      })
      |> Repo.edit_diff()

      # This is just noise
      {:ok, t} =
        %Thing{}
        |> Thing.changeset(%{description: "noise", input: %{}, name: "who cares"})
        |> Repo.create()

      # Edit ever other one for more noise
      if Integer.is_even(n) do
        t
        |> Thing.changeset(%{name: "aaaaaaaaaaaaa"})
        |> Repo.edit_diff()
      end
    end)

    # Controlled edits
    {:ok, _} =
      stale
      |> Thing.changeset(%{description: "previous"})
      |> Repo.edit_diff()

    {:ok, _} =
      stale
      |> Thing.changeset(%{name: "new!"})
      |> Repo.edit_diff()

    {:ok, _} =
      stale
      |> Thing.changeset(%{input: %{"yo" => "hey"}})
      |> Repo.edit_diff()

    # One more
    {:ok, _} =
      stale
      |> Thing.changeset(%{
        description: "latest",
        input: %{"doesn't" => "matter"},
        name: "latest name"
      })
      |> Repo.edit_diff()

    IO.puts("diff big boy over")
    Process.sleep(1_000)

    Ecto.Adapters.SQL.query!(Repo, "SELECT pg_size_pretty(pg_total_relation_size('replicas'));")
    |> IO.inspect(label: "diff size")

    # Get Latest
    start = System.monotonic_time(:millisecond)
    previous = Repo.previous_diff(Thing, id)

    # IO.inspect(time / 1000, label: "time in milliseconds")
    time_elapsed = abs(start - System.monotonic_time(:millisecond))

    IO.puts("#{time_elapsed} ms")

    assert match?(%{description: "previous", input: %{"yo" => "hey"}, name: "new!"}, previous)
  end

  @tag :skip
  test "latest with datetime" do
  end

  # make sure to test with multis!
end
