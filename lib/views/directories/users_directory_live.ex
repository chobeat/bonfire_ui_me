defmodule Bonfire.UI.Me.UsersDirectoryLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  # import Bonfire.UI.Me.Integration

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    current_user = current_user(socket.assigns)

    show_to =
      Bonfire.Common.Settings.get(
        [Bonfire.UI.Me.UsersDirectoryLive, :show_to],
        :users
      )

    if show_to ||
         maybe_apply(Bonfire.Me.Accounts, :is_admin?, socket.assigns[:__context__]) == true do
      if show_to == :guests or current_user || current_account(socket) do
        {title, users} =
          if params["instance_id"] do
            # TODO: pagination
            {l("Instance directory"),
             Bonfire.Me.Users.list(
               show: {:instance, params["instance_id"]},
               current_user: current_user
             )}
          else
            count = Bonfire.Me.Users.maybe_count()

            title =
              if(count,
                do: l("Users directory (%{total})", total: count),
                else: l("Users directory")
              )

            # TODO: pagination
            {title, Bonfire.Me.Users.list(current_user: current_user)}
          end
          |> debug("listed users")

        is_guest? = is_nil(current_user)

        {:ok,
         assign(
           socket,
           page_title: title,
           page: "users",
           selected_tab: :users,
           is_guest?: is_guest?,
           without_sidebar: is_guest?,
           without_secondary_widgets: is_guest?,
           no_header: is_guest?,
           nav_items: Bonfire.Common.ExtensionModule.default_nav(),
           search_placeholder: "Search users",
           users: users
         )}
      else
        throw(l("You need to log in before browsing the user directory"))
      end
    else
      throw(l("The user directory is disabled on this instance"))
    end
  end

  def handle_params(params, uri, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_params(
        params,
        uri,
        socket,
        __MODULE__
      )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )
end