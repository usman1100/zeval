defmodule ZevalCoreTest do
  use ExUnit.Case
  doctest ZevalCore

  test "greets the world" do
    assert ZevalCore.hello() == :world
  end
end
