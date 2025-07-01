class Prompts::CommandsController < ApplicationController
  def index
    if stale? etag: @tags
      render layout: false
    end
  end
end
