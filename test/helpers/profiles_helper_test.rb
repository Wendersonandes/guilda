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
end
