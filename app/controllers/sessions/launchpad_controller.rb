class Sessions::LaunchpadController < ApplicationController
  require_unauthenticated_access

  before_action :store_sig, only: :show
  before_action :restore_and_clear_sig, only: :update

  def show
  end

  def update
    if user = Current.account.signal_account.authenticate(sig: @sig).try(:peer)
      start_new_session_for user
      redirect_to after_authentication_url
    else
      render plain: "Authentication failed. This is probably a bug.", status: :unauthorized
    end
  end

  private
    def store_sig
      cookies[:_fizzy_launchpad_sig] = params.expect(:sig)
    end

    def restore_and_clear_sig
      @sig = cookies.delete :_fizzy_launchpad_sig
    end
end
