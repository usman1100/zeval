defmodule ZevalWeb.LayoutView do
  @moduledoc """
  Fallback layout view. LiveViews render their own full HTML.
  """
  use ZevalWeb, :view

  def render("root.html", %{inner_content: inner}) do
    inner
  end
end
