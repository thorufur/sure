require "test_helper"

class Transaction::AnalysisNoteTest < ActiveSupport::TestCase
  test "writes a document reference into the generated analysis note" do
    note = Transaction::AnalysisNote.from_result(
      "summary" => "Document found.",
      "documents" => [
        {
          "id" => 42,
          "title" => "Invoice",
          "reference_number" => "REF-2026-0042"
        }
      ]
    )

    assert_includes note, "Referenz: REF-2026-0042"
  end
end
