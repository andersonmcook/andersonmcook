# Immutable

This isn't true immutability, but effective immutability.

## Thoughts

Making copies is a good thing. It allows us to know the state of our system at a
particular time and to travel back to that point in time selectively or as a
whole.

We don't need to colocate our current state with our past state.

Reviving a previous state is necessary, but uncommon, whereas accessing and
manipulating the current state will happen constantly.

You can store changes instead of whole records, if space is a concern.

Replay will happen in order, so the copying of states should happen in order.

Copying can be tied to inserting/updating, or can happen asynchronously, to your
taste.

Application schemata/structs can change, and you may not want to put an old
record into a current schema.

## Metrics
 
Insert 1 record.

Randomly edit the record 20,000 times.

Insert 20,000 unrelated records.

Edit half of those unrelated records.

Make controlled edits to the initial record.

Begin metrics on table size and time to calculate previous version.

Average across runs.

| Method | Space used      | Time to calculate |
|--------|-----------------|-------------------|
| diff   | 7680 kb         | 152 ms            |
| full   | 10 mb           | 5 ms

* Note: the "full" method requires a complete data copy each edit, whereas the
  "diff" method does not.

## Database Instructions

`brew services start postgresql`

`createuser -d postgres`

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.



