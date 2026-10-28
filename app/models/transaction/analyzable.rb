module Transaction::Analyzable
  extend ActiveSupport::Concern

  ANALYSIS_STATUSES = %w[queued running completed needs_review failed].freeze

  def analysis
    value = extra&.fetch("analysis", nil)
    value.is_a?(Hash) ? value : {}
  end

  def analysis_status
    analysis["status"]
  end

  def analysis_active?
    analysis_status.in?(%w[queued running])
  end

  def queue_analysis!(requested_by:, prompt: nil)
    job_id = SecureRandom.uuid
    state = {
      "version" => 1,
      "job_id" => job_id,
      "status" => "queued",
      "requested_at" => Time.current.iso8601,
      "requested_by_id" => requested_by.id,
      "prompt" => prompt.to_s.strip.first(2_000).presence
    }.compact

    with_lock do
      update!(extra: (extra || {}).merge("analysis" => state))
    end

    job_id
  end

  def mark_analysis_running!(job_id)
    update_analysis_for_job!(job_id) do |state|
      state.merge("status" => "running", "started_at" => Time.current.iso8601)
    end
  end

  def complete_analysis!(job_id:, result:)
    normalized = Transaction::AnalysisResult.normalize(result)

    updated = update_analysis_for_job!(job_id) do |state|
      state.merge(
        "status" => normalized.fetch("status"),
        "completed_at" => Time.current.iso8601,
        "result" => normalized.except("status"),
        "error" => nil
      )
    end
    return false unless updated

    summary = Transaction::AnalysisNote.from_result(normalized)
    entry.update!(notes: Transaction::AnalysisNote.replace(entry.notes, summary)) if summary.present?
    true
  end

  def fail_analysis!(job_id:, message:)
    update_analysis_for_job!(job_id) do |state|
      state.merge(
        "status" => "failed",
        "completed_at" => Time.current.iso8601,
        "error" => message.to_s.first(500),
        "result" => nil
      )
    end
  end

  def analysis_payload
    original = extra&.dig("hibiscus", "original")
    amount_cents = (entry.amount.abs * 100).round.to_i

    {
      schema_version: 1,
      job_id: analysis.fetch("job_id"),
      transaction_id: id,
      callback_url: ENV["TRANSACTION_ANALYSIS_CALLBACK_URL"],
      prompt: analysis["prompt"],
      transaction: {
        name: entry.name,
        booking_date: entry.date.iso8601,
        amount_cents: amount_cents,
        signed_sure_amount_cents: (entry.amount * 100).round.to_i,
        direction: entry.amount.negative? ? "inflow" : "outflow",
        currency: entry.currency,
        pending: pending?,
        merchant: merchant&.name,
        category: category&.name,
        tags: tags.pluck(:name),
        notes: Transaction::AnalysisNote.without_analysis(entry.notes),
        hibiscus_original: original.is_a?(Hash) ? original : nil
      }.compact
    }.compact
  end

  private
    def update_analysis_for_job!(job_id)
      with_lock do
        state = analysis.deep_dup
        return false if state["job_id"].blank? || job_id.blank?
        return false unless ActiveSupport::SecurityUtils.secure_compare(state["job_id"].to_s, job_id.to_s)

        updated = yield(state)
        raise ArgumentError, "invalid analysis status" unless updated["status"].in?(ANALYSIS_STATUSES)

        update!(extra: (extra || {}).merge("analysis" => updated))
      end
      true
    end
end
