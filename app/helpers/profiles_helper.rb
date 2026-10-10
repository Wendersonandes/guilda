# Helpers to present a {Profile}'s contact information (Brazilian phone numbers, WhatsApp and
# Instagram links, and a masked email).
module ProfilesHelper
  # Formats a Brazilian phone number (digits only) for display.
  #
  # @param value [String, nil]
  # @return [String]
  def br_phone_display(value)
    digits = value.to_s.gsub(/\D/, "")
    case digits.length
    when 11 then "(#{digits[0, 2]}) #{digits[2, 7]}-#{digits[7, 4]}"
    when 10 then "(#{digits[0, 2]}) #{digits[2, 4]}-#{digits[6, 4]}"
    else value.to_s
    end
  end

  # Builds a WhatsApp (wa.me) link for a Brazilian number.
  #
  # @param value [String, nil] the number (with or without country code).
  # @return [String, nil]
  def whatsapp_url(value)
    digits = value.to_s.gsub(/\D/, "")
    return nil if digits.blank?

    digits = "55#{digits}" if digits.length == 11
    "https://wa.me/#{digits}"
  end

  # Canonical Instagram profile URL for a handle, @handle or URL.
  #
  # @param value [String, nil]
  # @return [String, nil]
  def instagram_url(value)
    return nil if value.blank?
    return value if value.match?(%r{\Ahttps?://}i)

    handle = value.delete_prefix("@")
    "https://instagram.com/#{handle}"
  end

  # Masks an email so it is not fully exposed until the visitor chooses to reveal it.
  #
  # @param email [String, nil]
  # @return [String]
  def masked_email(email)
    return "" if email.blank?

    local, domain = email.split("@", 2)
    return email if domain.blank?

    visible = local[0, 2].to_s
    "#{visible}***@#{domain}"
  end
end
