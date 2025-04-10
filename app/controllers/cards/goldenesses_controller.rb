class Cards::GoldenessesController < ApplicationController
  include CardScoped

  def create
    @card.promote_to_golden
    redirect_to @card
  end

  def destroy
    @card.demote_from_golden
    redirect_to @card
  end
end
