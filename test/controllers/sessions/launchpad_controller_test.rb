require "test_helper"

class Sessions::LaunchpadControllerTest < ActionDispatch::IntegrationTest
  test "show renders when not signed in" do
    get session_launchpad_path(params: { sig: "test-sig" })

    assert_response :success

    assert_equal cookies[:_fizzy_launchpad_sig], "test-sig"
  end

  test "create establishes a session when the sig is valid" do
    user = users(:david)
    cookies[:_fizzy_launchpad_sig] = user.signal_user.perishable_signature

    put session_launchpad_path

    assert_redirected_to root_url
    assert parsed_cookies.signed[:session_token]
  end

  test "returns 401 when the sig is invalid" do
    user = users(:david)
    cookies[:sig] = "not-valid"

    put session_launchpad_path

    assert_response :unauthorized
  end
end
