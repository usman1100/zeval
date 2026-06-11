defmodule ZevalWeb.ErrorJSON do
  @moduledoc """
  Renders JSON error responses for the API.
  """

  def render(template, _assigns) do
    %{error: Phoenix.Controller.status_message_from_template(template)}
  end
end
