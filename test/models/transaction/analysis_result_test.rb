require "test_helper"

class Transaction::AnalysisResultTest < ActiveSupport::TestCase
  test "preserves a document reference supplied by the analysis workflow" do
    result = Transaction::AnalysisResult.normalize(
      status: "completed",
      documents: [
        {
          id: 42,
          title: "Invoice",
          reference_number: "REF-2026-0042"
        }
      ]
    )

    assert_equal "REF-2026-0042", result.dig("documents", 0, "reference_number")
  end

  test "does not invent a reference when the workflow supplies none" do
    result = Transaction::AnalysisResult.normalize(
      status: "completed",
      documents: [ { id: 42, title: "Invoice" } ]
    )

    assert_not result.fetch("documents").first.key?("reference_number")
  end
end
