class TransactionAnalysesController < ApplicationController
  before_action :set_transaction

  def show
  end

  def create
    return unless require_account_permission!(@entry.account, :annotate, redirect_path: transaction_path(@entry))

    job_id = @transaction.queue_analysis!(requested_by: Current.user, prompt: analysis_params[:prompt])
    TransactionAnalysisJob.perform_later(@transaction.id, job_id)
    redirect_to transaction_analysis_path(@transaction), status: :see_other
  rescue ActiveJob::EnqueueError => error
    @transaction.fail_analysis!(job_id: job_id, message: error.message) if job_id
    redirect_to transaction_analysis_path(@transaction), alert: t("transaction_analyses.create.enqueue_failed"), status: :see_other
  end

  private
    def set_transaction
      @transaction = Current.family.transactions
                            .joins(entry: :account)
                            .merge(Account.accessible_by(Current.user))
                            .includes(:tags, :merchant, :category, entry: :account)
                            .find(params[:transaction_id])
      @entry = @transaction.entry
    end

    def analysis_params
      params.fetch(:analysis, {}).permit(:prompt)
    end
end
