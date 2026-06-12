defmodule ZevalWeb.RateLimiter do
  @moduledoc """
  Rate limiter using Hammer with ETS backend.

  Each endpoint group uses a different key prefix so their counters are
  independent.
  """

  use Hammer, backend: :ets
end
