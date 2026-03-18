defmodule TennisTrackerWeb.AuthController do
  use TennisTrackerWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias TennisTracker.Groups

  def success(conn, activity, user, _token) do
    return_to =
      case get_session(conn, :return_to) do
        nil -> post_login_path(user)
        path -> path
      end

    message =
      case activity do
        {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
        {:password, :reset} -> "Your password has successfully been reset"
        _ -> "You are now signed in"
      end

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        _ ->
          "Incorrect email or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:tennis_tracker)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end

  defp post_login_path(user) do
    case Groups.list_groups_for_user(user.id, actor: user) do
      {:ok, [single_group]} -> ~p"/g/#{single_group.slug}/teams"
      _ -> ~p"/groups"
    end
  end
end
