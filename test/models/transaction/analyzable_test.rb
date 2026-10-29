require "test_helper"

class Transaction::AnalyzableTest < ActiveSupport::TestCase
  setup do
    @transaction = transactions(:one)
    @entry = @transaction.entry
    @user = users(:family_admin)
    @transaction.update!(extra: {
      "hibiscus" => {
        "pending" => false,
        "original" => { "id" => "459", "betrag" => "-5.99" }
      }
    })
  end

  test "queues an isolated analysis without changing provider metadata" do
    job_id = @transaction.queue_analysis!(requested_by: @user, prompt: "  Apple purchase  ")

    assert_equal job_id, @transaction.reload.analysis["job_id"]
    assert_equal "queued", @transaction.analysis_status
    assert_equal "Apple purchase", @transaction.analysis["prompt"]
    assert_equal "459", @transaction.extra.dig("hibiscus", "original", "id")
  end

  test "queuing a new analysis removes the previous generated note and document links" do
    @entry.update!(notes: Transaction::AnalysisNote.replace(
      "Manual note",
      "Old result\nAmazon invoice: https://paperless.example/documents/12/details"
    ))

    @transaction.queue_analysis!(requested_by: @user, prompt: "Try again")

    assert_equal "queued", @transaction.reload.analysis_status
    assert_equal "Manual note", @entry.reload.notes
    assert_not_includes @entry.notes, Transaction::AnalysisNote::START_MARKER
    assert_not_includes @entry.notes, "paperless.example"
  end

  test "completes the current job and replaces only the generated note block" do
    @entry.update!(notes: "Manual note")
    job_id = @transaction.queue_analysis!(requested_by: @user)

    assert @transaction.complete_analysis!(job_id: job_id, result: {
      status: "completed",
      summary: "Matching Apple invoice found.",
      confidence: "high",
      amount_match: { booking_cents: 599, documents_cents: 599, exact: true },
      documents: [ { id: 12, title: "Apple receipt", url: "https://paperless.example/documents/12/details", amount_cents: 599 } ]
    })

    assert_equal "completed", @transaction.reload.analysis_status
    assert_includes @entry.reload.notes, "Manual note"
    assert_includes @entry.notes, Transaction::AnalysisNote::START_MARKER
    assert_includes @entry.notes, "Apple receipt"

    @transaction.queue_analysis!(requested_by: @user)
    second_job = @transaction.analysis["job_id"]
    @transaction.complete_analysis!(job_id: second_job, result: {
      status: "needs_review", summary: "A different result.", confidence: "low"
    })

    assert_equal 1, @entry.reload.notes.scan(Transaction::AnalysisNote::START_MARKER).size
    assert_includes @entry.notes, "A different result."
    assert_not_includes @entry.notes, "Apple receipt"
  end

  test "ignores a stale callback including its note" do
    current_job = @transaction.queue_analysis!(requested_by: @user)

    refute @transaction.complete_analysis!(job_id: SecureRandom.uuid, result: {
      status: "completed", summary: "Stale result", confidence: "high"
    })

    assert_equal current_job, @transaction.reload.analysis["job_id"]
    assert_not_includes @entry.reload.notes.to_s, "Stale result"
  end

  test "does not accept a callback without a queued job" do
    @transaction.update!(extra: @transaction.extra.except("analysis"))

    refute @transaction.complete_analysis!(job_id: nil, result: {
      status: "completed", summary: "Unsolicited result", confidence: "high"
    })

    assert_not_includes @entry.reload.notes.to_s, "Unsolicited result"
  end

  test "payload removes a previous generated analysis from notes" do
    @entry.update!(notes: Transaction::AnalysisNote.replace("Manual note", "Old generated result"))
    @transaction.queue_analysis!(requested_by: @user, prompt: "Find invoice")

    payload = @transaction.analysis_payload

    assert_equal "Manual note", payload.dig(:transaction, :notes)
    assert_equal 1_000, payload.dig(:transaction, :amount_cents)
    assert_equal "459", payload.dig(:transaction, :hibiscus_original, "id")
  end
end
