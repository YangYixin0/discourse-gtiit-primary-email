# Synthetic data only, for a disposable development database.
SiteSetting.title = "GTIIT Email Validation"
SiteSetting.gtiit_primary_email_enabled = true
SiteSetting.login_required = false
SiteSetting.must_approve_users = false
SiteSetting.invite_only = false
SiteSetting.allow_user_locale = true
SiteSetting.enable_secondary_emails = true
SiteSetting.require_change_email_confirmation = true
SiteSetting.default_theme_id = Theme.horizon_theme.id
SiteSetting.min_post_length = 5
SiteSetting.min_first_post_length = 5
SiteSetting.force_https = false

users = {}
%w[alice bob charlie admin].each do |name|
  u = User.find_by(username: name) || User.create!(
    username: name, name: "Synthetic #{name.capitalize}", email: "#{name}@example.test",
    password: "Synthetic-Validation-2026!", active: true, approved: true,
    trust_level: 2, admin: name == "admin"
  )
  u.update!(locale: "en")
  u.activate unless u.email_confirmed?
  u.user_profile.update!(bio_raw: "Fictional account for isolated plugin validation.")
  users[name] = u
end
users["alice"].user_emails.find_or_create_by!(email: "alice.secondary@example.test", primary: false)
authors = (1..20).map do |i|
  User.find_by(username: "author#{i}") || User.create!(
    username: "author#{i}", name: "Synthetic Author #{i}",
    email: i == 1 ? "long.primary.address.for.mobile.wrapping.validation@example.test" : "author#{i}@example.test",
    password: "Synthetic-Validation-2026!", active: true, approved: true, trust_level: 2
  )
end
authors.each { |u| u.activate unless u.email_confirmed? }
topic = Topic.find_by(title: "Synthetic many author email validation")
unless topic
  first = PostCreator.create!(users["alice"], title: "Synthetic many author email validation", raw: "Fictional original post predating the primary email change.", skip_validations: true)
  topic = first.topic
  authors.each { |u| PostCreator.create!(u, topic_id: topic.id, raw: "Synthetic reply by #{u.username} for layout and SQL validation.", skip_validations: true) }
  PostCreator.create!(users["bob"], topic_id: topic.id, raw: "Synthetic viewer Bob contributes another reply.", skip_validations: true)
end
group = Group.find_or_create_by!(name: "validation_private")
group.add(users["alice"])
category = Category.find_by(name: "Synthetic private") || Category.create!(name: "Synthetic private", user: users["admin"])
category.set_permissions(group.name => :full)
category.save!
private_topic = Topic.find_by(title: "Synthetic restricted topic") || PostCreator.create!(users["alice"], title: "Synthetic restricted topic", raw: "Fictional restricted content for access checks.", category: category.id, skip_validations: true).topic
pm = Topic.find_by(title: "Synthetic private message") || PostCreator.create!(users["alice"], title: "Synthetic private message", raw: "Fictional private message to Charlie only.", archetype: Archetype.private_message, target_usernames: "charlie", skip_validations: true).topic
File.write("/workspace/fixture.json", JSON.pretty_generate({ topic_id: topic.id, private_topic_id: private_topic.id, pm_id: pm.id, users: users.transform_values(&:id), theme: Theme.horizon_theme.name, theme_id: Theme.horizon_theme.id }))
puts "SYNTHETIC_SEED_COMPLETE"
