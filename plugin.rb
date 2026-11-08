# frozen_string_literal: true

# name: discourse-gtiit-primary-email
# about: Show primary email addresses to authenticated forum members.
# version: 0.1.0
# authors: GTIIT forum

register_asset "stylesheets/common/gtiit-primary-email.scss"
enabled_site_setting :gtiit_primary_email_enabled

after_initialize do
  require_relative "lib/gtiit_primary_email/policy"

  add_to_serializer(
    :user_card,
    :gtiit_primary_email,
    include_condition: -> { GtiitPrimaryEmail::Policy.profile?(scope, object) },
  ) { object.email }

  add_to_serializer(
    :post,
    :gtiit_primary_email,
    include_condition: -> { GtiitPrimaryEmail::Policy.post?(scope, object) },
  ) { object.user.email }

  TopicView.on_preload do |topic_view|
    next unless SiteSetting.gtiit_primary_email_enabled
    next unless GtiitPrimaryEmail::Policy.member?(topic_view.guardian)

    ActiveRecord::Associations::Preloader.new(
      records: topic_view.posts.to_a,
      associations: {
        user: :primary_email,
      },
    ).call
  end
end
