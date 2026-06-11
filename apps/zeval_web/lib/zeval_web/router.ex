defmodule ZevalWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", ZevalWeb do
    pipe_through :api
  end
end
