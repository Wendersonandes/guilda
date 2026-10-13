require "test_helper"

class ProfilesHelperTest < ActionView::TestCase
  test "builds a wa.me link with the country code for an 11-digit number" do
    assert_equal "https://wa.me/5511999999999", whatsapp_url("11999999999")
  end

  test "keeps an already-prefixed number unchanged" do
    assert_equal "https://wa.me/5511999999999", whatsapp_url("5511999999999")
  end

  test "strips non-digit characters" do
    assert_equal "https://wa.me/5511999999999", whatsapp_url("(11) 99999-9999")
  end

  test "returns nil for a blank number" do
    assert_nil whatsapp_url(nil)
    assert_nil whatsapp_url("")
  end

  test "appends a URL-encoded prefilled message when given" do
    url = whatsapp_url("11999999999", text: "Olá, tudo bem?")

    assert_equal "https://wa.me/5511999999999?text=Ol%C3%A1%2C%20tudo%20bem%3F", url
    assert_not_includes url, " "
  end

  test "omits the message parameter when no text is given" do
    assert_not_includes whatsapp_url("11999999999", text: nil), "?text="
    assert_not_includes whatsapp_url("11999999999", text: ""), "?text="
  end

  test "formats an 11-digit mobile without dropping digits" do
    assert_equal "(11) 98765-4321", br_phone_display("11987654321")
    assert_equal "11987654321", br_phone_display("11987654321").gsub(/\D/, "")
  end

  test "formats a 10-digit landline" do
    assert_equal "(11) 3265-4321", br_phone_display("1132654321")
  end

  test "drops the 55 country code before formatting a mobile" do
    assert_equal "(11) 98765-4321", br_phone_display("5511987654321")
  end

  test "returns the original value when it cannot be formatted" do
    assert_equal "abc", br_phone_display("abc")
  end
end
