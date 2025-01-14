defmodule Bonfire.UI.Me.UsersDirectoryLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  # import Bonfire.UI.Me

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
        instance_id =
          if instance = params["instance"] do
            case ulid(instance) do
              nil -> id(Bonfire.Federate.ActivityPub.Instances.get_by_domain(instance))
              instance_id -> instance_id
            end
          end

        {title, %{page_info: page_info, edges: edges}} =
          list_users(current_user, params, instance_id)

        is_guest? = is_nil(current_user)

        {:ok,
         assign(
           socket,
           page_title: title,
           page: "users",
           instance_id: instance_id,
           is_remote?: not is_nil(instance_id),
           selected_tab: :users,
           is_guest?: is_guest?,
           without_sidebar: is_guest?,
           without_secondary_widgets: is_guest?,
           no_header: is_guest?,
           nav_items: Bonfire.Common.ExtensionModule.default_nav(),
           search_placeholder: "Search users",
           users: edges,
           page_info: page_info
         )}
      else
        throw(l("You need to log in before browsing the user directory"))
      end
    else
      throw(l("The user directory is disabled on this instance"))
    end
  end

  def handle_event("load_more", attrs, socket) do
    {_title, %{page_info: page_info, edges: edges}} =
      list_users(current_user(socket.assigns), attrs, e(socket.assigns, :instance_id, nil))

    {:noreply,
     socket
     |> assign(
       loaded: true,
       users: e(socket.assigns, :users, []) ++ edges,
       page_info: page_info
     )}
  end

  def list_users(current_user, params, instance_id \\ nil) do
    paginate =
      input_to_atoms(params)
      |> debug

    if instance_id do
      {l("Instance directory"),
       Bonfire.Me.Users.list_paginated(
         show: {:instance, instance_id},
         current_user: current_user,
         paginate: paginate
       )}
    else
      count = Bonfire.Me.Users.maybe_count()

      title =
        if(count,
          do: l("Users directory (%{total})", total: count),
          else: l("Users directory")
        )

      {title,
       Bonfire.Me.Users.list_paginated(
         current_user: current_user,
         paginate: paginate
       )}
    end
    |> debug("listed users")
  end
end
