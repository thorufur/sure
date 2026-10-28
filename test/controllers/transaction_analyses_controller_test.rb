require "test_helper"

class TransactionAnalysesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in @user = users(:family_admin)
    @transaction = transactions(:one)
  end

  test "shows the analysis dialog for an accessible transaction" do
    get transaction_analysis_url(@transaction), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal"
    assert_select "textarea[name='analysis[prompt]']"
  end

  test "queues an analysis job" do
    assert_enqueued_with(job: TransactionAnalysisJob) do
      post transaction_analysis_url(@transaction), params: { analysis: { prompt: "Likely Apple" } }
    end

    assert_redirected_to transaction_analysis_path(@transaction)
    assert_equal "queued", @transaction.reload.analysis_status
    assert_equal "Likely Apple", @transaction.analysis["prompt"]
  end

  test "does not expose another family's transaction" do
    account = Account.create!(
      family: families(:empty), owner: users(:empty), name: "Other checking",
      currency: "USD", balance: 0, status: :active, accountable: Depository.new
    )
    entry = account.entries.create!(
      name: "Private", date: Date.current, amount: 1, currency: "USD",
      entryable: Transaction.new
    )

    get transaction_analysis_url(entry.transaction)

    assert_response :not_found
  end
end
