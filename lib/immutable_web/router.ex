defmodule ImmutableWeb.Router do
  use ImmutableWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ImmutableWeb do
    pipe_through :api
  end
end
