# frozen_string_literal: true

require "rails_helper"
require 'openssl'
require 'json'
require_relative '../spec_helper'

RSpec.describe ::Patreon::PatreonWebhookController do
  include_context "spec helper"

  before do
    SiteSetting.queue_jobs = false
  end

  context "index" do

    context 'checking headers' do

      it 'raises InvalidAccess error without header params' do
        Jobs.expects(:enqueue).with(:patreon_sync_patrons_to_groups).never
        post '/patreon/webhook'
      end

      it 'raises InvalidAccess error with invalid header params' do
        Jobs.expects(:enqueue).with(:patreon_sync_patrons_to_groups).never
        post '/patreon/webhook', headers: {
          'X-Patreon-Event': '',
          'X-Patreon-Signature': ''
        }
      end

    end

    context 'enqueue job' do

      let(:body) { get_patreon_response('member.json') }
      let(:digest) { OpenSSL::Digest::MD5.new }
      let(:secret) { SiteSetting.patreon_webhook_secret = "WEBHOOK SECRET" }
      let(:user) { Fabricate(:user, email: "roo@aar.com") }

      before do
        user
        Fabricate(:patreon_campaign, external_id: "123456")
      end

      def add_pledge
        pledge_data = JSON.parse(body)
        Patreon.update(pledge_data)

        pledge_data
      end

      def post_request(body, event)
        post '/patreon/webhook', params: body, headers: {
          'X-Patreon-Event': "members:pledge:#{event}",
          'X-Patreon-Signature': OpenSSL::HMAC.hexdigest(digest, secret, body)
        }
      end

      it "for event members:pledge:create" do
        expect {
          post_request(body, "create")
        }.to change { Customer.count }.by(1)
          .and change { Patreon::Member.count }.by(1)

        expect(Patreon.default_group.users).to include(user)
      end

      it "for event members:pledge:update" do
        pledge_data = add_pledge
        pledge = pledge_data['data']
        pledge['attributes']['currently_entitled_amount_cents'] = 900
        patron_id = pledge['relationships']['user']['data']['id']
        pledge_data = JSON.pretty_generate(pledge_data)

        expect(Patreon::Member.last.amount).to eq(3)
        post_request(pledge_data, "update")
        expect(Patreon::Member.last.amount).to eq(9)
      end

      it "for event members:pledge:delete" do
        pledge_data = add_pledge
        pledge_data['data']['attributes']['patron_status'] = "former_patron"
        pledge_data = JSON.pretty_generate(pledge_data)

        expect(Patreon::Member.last.status).to eq(Patreon::Member.statuses[:active])
        expect {
          post_request(pledge_data, "delete")
        }.to change { Patreon.default_group.users.count }.by(-1)
        expect(Patreon::Member.last.status).to eq(Patreon::Member.statuses[:inactive])
      end

    end

  end

end
