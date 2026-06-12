defmodule ZevalWeb do
  @moduledoc """
  The web layer for Zeval Engine.

  Defines the `__using__` macros used by controllers and views.
  """

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]
      import Plug.Conn
      import ZevalWeb.JsonHelpers
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: Application.app_dir(:zeval_web, "lib/zeval_web/templates"),
        namespace: ZevalWeb
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {ZevalWeb.LayoutView, :root}

      unquote(view_helpers())
    end
  end

  defp view_helpers do
    quote do
      import Phoenix.Component
      import Phoenix.LiveView
      import Phoenix.LiveView.Helpers
    end
  end
end