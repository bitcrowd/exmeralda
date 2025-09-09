defmodule ExmeraldaWeb.Admin.LiveHooks do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  def on_mount(:global, _params, _session, socket) do
    {:cont, attach_hook(socket, :assign_current_path, :handle_params, &assign_current_path/3)}
  end

  defp assign_current_path(_params, url, socket) do
    uri = URI.parse(url) |> current_path()

    {:cont, assign(socket, :current_path, uri)}
  end

  defp current_path(%URI{:path => path}), do: path
end
