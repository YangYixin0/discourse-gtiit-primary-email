# frozen_string_literal: true

require "rails_helper"

RSpec.describe GtiitPrimaryEmail::Policy do
  fab!(:viewer) { Fabricate(:user, trust_level: 2, approved: true) }
  fab!(:author) { Fabricate(:user, trust_level: 2, approved: true) }
  fab!(:post) { Fabricate(:post, user: author) }

  before { SiteSetting.gtiit_primary_email_enabled = true }

  def guardian_for(user = viewer, env = {})
    Guardian.new(user, ActionDispatch::TestRequest.create(env))
  end

  def payloads(guardian)
    [
      UserCardSerializer.new(author.reload, scope: guardian, root: false).as_json,
      UserSerializer.new(author, scope: guardian, root: false).as_json,
      PostSerializer.new(post.reload, scope: guardian, root: false).as_json,
    ]
  end

  it "exposes only the primary email in all three payloads" do
    secondary = Fabricate(:secondary_email, user: author)

    payloads(guardian_for).each do |payload|
      expect(payload[:gtiit_primary_email]).to eq(author.email)
      expect(payload.to_json).not_to include(secondary.email)
    end
  end

  it "reads the changed primary email for existing posts and profiles" do
    old_email = author.email
    author.update!(email: "updated@gtiit.example")

    payloads(guardian_for).each do |payload|
      expect(payload[:gtiit_primary_email]).to eq(author.email)
      expect(payload[:gtiit_primary_email]).not_to eq(old_email)
    end
  end

  it "omits the field for anonymous viewers and absent request contexts" do
    [guardian_for(nil), Guardian.new(viewer)].each do |guardian|
      payloads(guardian).each { |payload| expect(payload).not_to have_key(:gtiit_primary_email) }
    end
  end

  it "omits the field for both API authentication methods" do
    [
      Auth::DefaultCurrentUserProvider::API_KEY_ENV,
      Auth::DefaultCurrentUserProvider::USER_API_KEY_ENV,
    ].each do |key|
      payloads(guardian_for(viewer, key => true)).each do |payload|
        expect(payload).not_to have_key(:gtiit_primary_email)
      end
    end
  end

  it "omits the field for inactive, unapproved and suspended viewers" do
    SiteSetting.must_approve_users = true
    [
      Fabricate(:user, active: false),
      Fabricate(:user, approved: false),
      Fabricate(:user, suspended_till: 1.day.from_now),
    ].each do |user|
      payloads(guardian_for(user)).each do |payload|
        expect(payload).not_to have_key(:gtiit_primary_email)
      end
    end
  end

  it "omits the field when disabled" do
    SiteSetting.gtiit_primary_email_enabled = false

    payloads(guardian_for).each { |payload| expect(payload).not_to have_key(:gtiit_primary_email) }
  end

  it "respects hidden profile permissions" do
    SiteSetting.allow_users_to_hide_profile = true
    author.user_option.update!(hide_profile: true)

    payload = UserCardSerializer.new(author, scope: guardian_for, root: false).as_json

    expect(payload).not_to have_key(:gtiit_primary_email)
  end

  it "omits the post field when the viewer cannot access its private topic" do
    private_post = Fabricate(:private_message_post)

    payload = PostSerializer.new(private_post, scope: guardian_for, root: false).as_json

    expect(payload).not_to have_key(:gtiit_primary_email)
  end
end
