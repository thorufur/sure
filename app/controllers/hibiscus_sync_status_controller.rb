class HibiscusSyncStatusController < ApplicationController
  def show
    @bank_status = HibiscusBankClient.visible_status(Current.user)
    @frame_id = params[:frame_id].to_s
    @frame_id = "hibiscus-sync-status" unless @frame_id.match?(/\A[a-z0-9-]+\z/)
    render layout: false
  end
end
