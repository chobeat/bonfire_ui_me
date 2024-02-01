defmodule Bonfire.UI.Me.GuestProfileLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :map
  prop boundary_preset, :any, default: nil
  prop members, :any, default: nil
  prop moderators, :any, default: nil
end
