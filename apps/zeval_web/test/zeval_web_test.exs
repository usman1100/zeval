defmodule ZevalWebTest do
  use ExUnit.Case
  doctest ZevalWeb

  test "greets the world" do
    assert ZevalWeb.hello() == :world
  end
end
