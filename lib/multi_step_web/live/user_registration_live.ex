defmodule MultiStepWeb.UserRegistrationLive do
  use MultiStepWeb, :live_view

  alias MultiStep.Accounts
  alias MultiStep.Accounts.User

  def total_steps, do: 2

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
            Sign in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="registration_form"
        phx-submit={if @current_step == total_steps(), do: "save", else: "next-step"}
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/users/log_in?_action=registered"}
        method="post"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input
          field={@form[:email]}
          type={if @current_step == 1, do: "email", else: "hidden"}
          label="Email"
          required
        />

        <.input
          field={@form[:password]}
          type={if @current_step == total_steps(), do: "password", else: "hidden"}
          label="Password"
          required
        />

        <:actions>
          <.button :if={@current_step > 1} type="button" phx-click="prev-step">Back</.button>

          <.button phx-disable-with="Saving..." class="w-full">
            <%= if @current_step < total_steps(), do: "Next", else: "Create account" %>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(current_step: 1)
      |> assign(trigger_submit: false, check_errors: false)
      |> assign(changeset: changeset)
      |> assign_form(changeset)

    {:ok, socket}
  end

  def handle_event("prev-step", _params, socket) do
    new_step = max(socket.assigns.current_step - 1, 1)
    {:noreply, assign(socket, :current_step, new_step)}
  end

  def handle_event("next-step", _params, socket) do
    current_step = socket.assigns.current_step
    changeset = socket.assigns.changeset

    step_invalid =
      case current_step do
        1 -> Enum.any?(Keyword.keys(changeset.errors), fn k -> k in [:email] end)
        2 -> Enum.any?(Keyword.keys(changeset.errors), fn k -> k in [:password] end)
        _ -> true
      end

    new_step = if step_invalid, do: current_step, else: current_step + 1
    {:noreply, assign(socket, :current_step, new_step)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)

    socket =
      socket
      |> assign(changeset: changeset)
      |> assign_form(Map.put(changeset, :action, :validate))

    {:noreply, socket}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
