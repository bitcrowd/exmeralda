defmodule ExmeraldaWeb.LayoutComponents do
  use ExmeraldaWeb, :component

  def navbar_layout(assigns) do
    ~H"""
    <nav class="navbar bg-base-100 shadow-sm" aria-label="main">
      <div class="flex-1">
        <label :if={assigns[:drawer]} for="nav-drawer">
          <.icon name="hero-bars-3" class="m-2 lg:hidden" />
        </label>
        <a class="btn btn-ghost text-xl" href={~p"/"}>Exmeralda</a>
      </div>
      <div class="flex-none">
        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="btn btn-ghost btn-circle avatar">
            <div class="w-10 rounded-full">
              <img title={@user.name} src={@user.avatar_url} />
            </div>
          </div>
          <ul
            tabindex="0"
            class="menu menu-sm dropdown-content bg-base-300 rounded-box z-1 mt-3 w-52 p-2 shadow"
          >
            <li>
              <.link href={~p"/auth/settings"}>
                <.icon name="hero-cog-6-tooth" />
                {gettext("Settings")}
              </.link>
            </li>
            <li>
              <.link href={~p"/auth/log_out"} method="delete">
                <.icon name="hero-arrow-right-start-on-rectangle" />
                {gettext("Logout")}
              </.link>
            </li>
          </ul>
        </div>
      </div>
    </nav>
    <.drawer :if={assigns[:drawer]} drawer_id="nav-drawer" inside_navbar>
      <:side>
        {render_slot(@drawer)}
      </:side>
      {render_slot(@inner_block)}
    </.drawer>
    <div :if={!assigns[:drawer]} class="p-5">
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp drawer(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open">
      <input id={@drawer_id} type="checkbox" class="drawer-toggle" />
      <div class={["drawer-side z-40", full_screen_height(assigns)]}>
        <label for={@drawer_id} aria-label="close sidebar" class="drawer-overlay"></label>
        <nav class="bg-base-200 min-h-full flex flex-col place-content-between" aria-label="chats">
          <div>
            {render_slot(@side)}
          </div>
          <div>
            <a
              href="https://github.com/bitcrowd/exmeralda/"
              class="p-4 m-2 rounded-lg flex items-center gap-2 text-gray-500 text-sm group hover:bg-white dark:bg-base-300"
            >
              <img
                src={~p"/images/logo-github-light.svg"}
                width="98"
                height="96"
                alt="github logo"
                class="max-w-10 dark:hidden dark:group-hover:block"
              />
              <img
                src={~p"/images/logo-github-dark.svg"}
                width="98"
                height="96"
                alt="github logo"
                class="max-w-10 hidden dark:block dark:group-hover:hidden"
              /> Contribute on github
            </a>
            <hr class="mx-2 border-base-100" />
            <a
              href="https://bitcrowd.net"
              class="p-4 m-2 rounded-lg flex flex-col gap-2 text-gray-500 text-sm group hover:bg-white dark:bg-base-300"
            >
              Built in Berlin with ♥ by <span class="sr-only">bitcrowd</span>
              <img
                src={~p"/images/logo-bitcrowd-light.svg"}
                width="303"
                height="93"
                alt="bitcrowd logo, a dirigible airship flying amongst clouds"
                class="max-w-32 dark:hidden dark:group-hover:block"
              />
              <img
                src={~p"/images/logo-bitcrowd-dark.svg"}
                width="303"
                height="93"
                alt="bitcrowd logo, a dirigible airship flying amongst clouds"
                class="max-w-32 hidden dark:block dark:group-hover:hidden"
              />
            </a>
          </div>
        </nav>
      </div>
      <main class="drawer-content">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  def hero_layout(assigns) do
    ~H"""
    <div class={["hero bg-base-200", full_screen_height(assigns)]}>
      <div class="hero-content">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  def full_screen_height(assigns) do
    if Map.has_key?(assigns, :inside_navbar), do: "h-[calc(100vh-4rem)]", else: "h-screen"
  end

  def admin_nav_layout(assigns) do
    ~H"""
    <.navbar_layout user={@user}>
      <:drawer>
        <.admin_nav current_path={@current_path} />
      </:drawer>
      <div class="p-4">
        {render_slot(@inner_block)}
      </div>
    </.navbar_layout>
    """
  end

  @admin_nav_items [
    %{href: "/admin/library", icon: "inbox-stack", label: gettext("Libraries")}
  ]
  def admin_nav(assigns) do
    assigns = assign_new(assigns, :admin_nav_items, fn -> @admin_nav_items end)

    ~H"""
    <ul class="menu menu-vertical w-full">
      <li :for={item <- @admin_nav_items}>
        <a
          href={item.href}
          class={["btn justify-start gap-4", current_nav?(item.href, @current_path) && "btn-active"]}
        >
          <.icon name={"hero-#{item.icon}"} />
          {item.label}
        </a>
      </li>
    </ul>
    """
  end

  defp current_nav?(href, current_path) do
    String.starts_with?(current_path, href)
  end
end
