defmodule Bonfire.UI.Me.ProfileLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.Me.Integration
  import Untangle

  # alias Bonfire.Me.Fake
  # declare_nav_link(l("Profile"), page: "feed", icon: "heroicons-solid:newspaper")

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(
        %{"remote_follow" => _, "username" => _username} = _params,
        _session,
        socket
      ) do
    # TODO?
    {:ok, socket}
  end

  def mount(params, _session, socket) do
    # debug(params)
    {:ok, socket |> assign(default_assigns())}
  end

  def tab(selected_tab) do
    case maybe_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> :timeline
    end
    |> debug(selected_tab)
  end

  defp maybe_init(
         %{"username" => load_username} = params,
         %{assigns: %{user: %{character: %{username: loaded_username}}}} = socket
       )
       when load_username == loaded_username do
    debug("skip (re)loading user")
    debug(loaded_username, "old user")
    debug(load_username, "load new user")
    socket
  end

  defp maybe_init(params, socket) do
    init(params, socket)
  end

  defp init(params, socket) do
    debug(params)
    username = Map.get(params, "username") || Map.get(params, "id")

    current_user = current_user(socket)
    current_username = e(current_user, :character, :username, nil)

    user =
      (params[:user] ||
         case username do
           nil ->
             current_user

           username when username == current_username ->
             current_user

           "@" <> username ->
             get(username)

           username ->
             get(username)
         end)
      |> repo().maybe_preload(:shared_user)

    # debug(user)

    # show remote users only to logged in users
    if user && (current_username || Integration.is_local?(user)) do
      # debug(
      #   Bonfire.Boundaries.Controlleds.list_on_object(user),
      #   "boundaries on user profile"
      # )

      following? =
        current_user && current_user.id != user.id &&
          module_enabled?(Bonfire.Social.Follows, current_user) &&
          Bonfire.Social.Follows.following?(user, current_user)

      # situation = Bonfire.Social.Block.LiveHandler.preload([%{__context__: socket.assigns.__context__, id: id(user), object_id: id(user), object: user, current_user: current_user}], caller_module: __MODULE__)
      # IO.inspect(situation, label: "situation2")
      # smart_input_prompt = if current_username == e(user, :character, :username, ""), do: l( "Write something..."), else: l("Write something for ") <> e(user, :profile, :name, l("this person"))
      # smart_input_prompt = nil

      # smart_input_text =
      #   if current_username == e(user, :character, :username, ""),
      #     do: "",
      #     else: "@" <> e(user, :character, :username, "") <> " "

      # preload(user, socket)
      socket
      |> assign(user_assigns(user, current_username, following?))
      |> assign_new(:selected_tab, fn -> "timeline" end)
      |> assign(:character_type, :user)
      |> assign(:ghosted, nil)

      # |> assign_global(
      # following: following || [],
      # search_placeholder: search_placeholder,
      # smart_input_opts: %{prompt: smart_input_prompt, text_suggestion: smart_input_text}

      # to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), ulid(user)}]
      # )
    else
      if user do
        # redir to login and then come back to this page
        # redir to remote profile
        if Map.get(params, "remote_interaction") do
          path = path(user)

          socket
          |> set_go_after(path)
          |> assign_flash(
            :info,
            l("Please login first, and then... ") <>
              " " <> e(socket, :assigns, :flash, :info, "")
          )
          |> redirect_to(path(:login) <> go_query(path))
        else
          redirect(socket,
            external: canonical_url(user)
          )
        end
      else
        with true <- String.trim(username, "@") |> String.contains?("@"),
             {:ok, user} <-
               Bonfire.Federate.ActivityPub.AdapterUtils.get_or_fetch_and_create_by_username(
                 username,
                 fetch_collection: :async
               ) do
          init(params |> Map.put(:user, user), socket)
        else
          _ ->
            socket
            |> assign_flash(:error, l("Profile not found"))
            |> redirect_to(path(:error, :not_found))
        end
      end
    end
  end

  # defp preload(user, socket) do
  #   view_pid = self()
  #   # Here we're checking if the user is ghosted / silenced by user or instance
  #   IO.inspect("preload test")
  #   Task.start(fn ->
  #     ghosted? = Bonfire.Boundaries.Blocks.is_blocked?(user, :ghost, current_user: current_user(socket)) |> debug("ghosted?")
  #     ghosted_instance_wide? = Bonfire.Boundaries.Blocks.is_blocked?(user, :ghost, :instance_wide) |> debug("ghosted_instance_wide?")
  #     silenced? = Bonfire.Boundaries.Blocks.is_blocked?(user, :silence, current_user: current_user(socket)) |> debug("silenced?")
  #     silenced_instance_wide? = Bonfire.Boundaries.Blocks.is_blocked?(user, :silence, :instance_wide) |> debug("silenced_instance_wide?")
  #     result = %{
  #       ghosted?: ghosted?,
  #       ghosted_instance_wide?: ghosted_instance_wide?,
  #       silenced?: silenced?,
  #       silenced_instance_wide?: silenced_instance_wide?
  #     }
  #     send(view_pid, {:block_status, result})
  #   end)

  # end

  # def handle_info({:block_status, result}, socket) do
  #   IO.inspect(result, label: "API CALL DONE")
  #   {:noreply, assign(socket, block_status: result)}
  # end

  def get(username) do
    username =
      String.trim_trailing(
        username,
        "@" <> Bonfire.Common.URIs.instance_domain()
      )

    with {:ok, user} <- Bonfire.Me.Users.by_username(username) do
      user
    else
      _ ->
        # handle other character types beyond User
        with {:ok, character} <- Bonfire.Common.Pointers.get(username) do
          character
        else
          _ ->
            nil
        end
    end
  end

  def default_assigns() do
    [
      smart_input: true,
      feed: nil,
      page_info: [],
      page: "profile",
      page_title: l("Profile"),
      feed_title: l("User timeline"),
      back: true,
      # without_sidebar: true,
      # the user to display
      nav_items: Bonfire.Common.ExtensionModule.default_nav(:bonfire_ui_social),
      user: %{},
      canonical_url: nil,
      character_type: nil,
      sidebar_widgets: [
        guests: [
          secondary: [
            {Bonfire.Tag.Web.WidgetTagsLive, []},
            {Bonfire.UI.Me.WidgetAdminsLive, []}
          ]
        ],
        users: [
          secondary: [
            {Bonfire.Tag.Web.WidgetTagsLive, []},
            {Bonfire.UI.Me.WidgetAdminsLive, []}
          ]
        ]
      ],
      interaction_type: l("follow"),
      follows_me: false,
      no_index: false
    ]
  end

  def user_assigns(user, current_username, following? \\ false) do
    name = e(user, :profile, :name, l("Someone"))

    title =
      if current_username == e(user, :character, :username, ""),
        do: l("Your profile"),
        else: name

    # search_placeholder = if current_username == e(user, :character, :username, ""), do: "Search my profile", else: "Search " <> e(user, :profile, :name, "this person") <> "'s profile"
    [
      page_title: title,
      user: user,
      canonical_url: canonical_url(user),
      name: name,
      follows_me: following?,
      no_index:
        Bonfire.Me.Settings.get([Bonfire.Me.Users, :undiscoverable], false, current_user: user)
    ]
  end

  def do_handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["posts", "boosts", "timeline"] do
    debug(tab, "load tab")

    Bonfire.Social.Feeds.LiveHandler.user_feed_assign_or_load_async(
      tab,
      nil,
      params,
      socket
    )
  end

  # WIP: Include circles in profile without redirecting to circles page
  # def do_handle_params(%{"tab" => tab} = params, _url, socket)
  #     when tab in ["circles"] do
  #   debug(tab, "load tab")
  #   current_user = current_user(socket)
  #   user = e(socket, :assigns, :user, nil)
  #   circles =
  #     Bonfire.Boundaries.Circles.list_my_with_counts(current_user, exclude_stereotypes: true)
  #     |> repo().maybe_preload(encircles: [subject: [:profile]])

  #     {:noreply,
  #     assign(
  #       socket,
  #       loading: false,
  #       user: user,
  #       showing_within: e(socket, :assigns, :showing_within, nil),
  #       selected_tab: "circles",
  #       circles: circles,
  #     )}
  # end

  def do_handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["followers", "followed", "requests", "requested"] do
    debug(tab, "load tab")

    {:noreply,
     assign(
       socket,
       Bonfire.Social.Feeds.LiveHandler.load_user_feed_assigns(
         tab,
         nil,
         params,
         socket
       )

       # |> debug("ffff")
     )}
  end

  def do_handle_params(
        %{"username" => "%40" <> username} = _params,
        _url,
        socket
      ) do
    debug("rewrite encoded @ in URL")
    {:noreply, patch_to(socket, "/@" <> String.replace(username, "%40", "@"), replace: true)}
  end

  def do_handle_params(%{"tab" => tab} = _params, _url, socket) do
    debug(tab, "unknown tab, maybe from another extension?")

    {:noreply,
     assign(socket,
       selected_tab: tab
     )}
  end

  def do_handle_params(params, _url, socket) do
    debug(params, "load default tab")

    do_handle_params(
      Map.merge(params || %{}, %{"tab" => "timeline"}),
      nil,
      socket
    )
  end

  def handle_params(params, uri, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_params(
        params,
        uri,
        maybe_init(params, socket),
        __MODULE__,
        &do_handle_params/3
      )

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

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
