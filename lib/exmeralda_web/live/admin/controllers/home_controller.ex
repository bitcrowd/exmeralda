defmodule ExmeraldaWeb.Admin.HomeController do
  use ExmeraldaWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: ~p"/admin/library")
  end
end
