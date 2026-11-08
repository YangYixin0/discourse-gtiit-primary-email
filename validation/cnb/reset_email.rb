u = User.find_by!(username: "alice")
u.email_change_requests.destroy_all
u.primary_email.update!(email: "alice@example.test")
SiteSetting.disable_emails = "no"
SiteSetting.gtiit_primary_email_enabled = true
puts "SYNTHETIC_EMAIL_RESET_COMPLETE"
