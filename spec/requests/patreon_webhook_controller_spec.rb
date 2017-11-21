require "rails_helper"
require 'openssl'

RSpec.describe ::Patreon::PatreonWebhookController do

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

      before do
        SiteSetting.patreon_webhook_secret = "WEBHOOK SECRET"
      end

      it "for correct params" do
        digest = OpenSSL::Digest::MD5.new
        raw_post = OpenSSL::HMAC.new(SiteSetting.patreon_webhook_secret, digest).to_s

        Jobs.expects(:enqueue).with(:patreon_sync_patrons_to_groups)
        post '/patreon/webhook', params: raw_post, headers: {
          'X-Patreon-Event': 'pledges:create',
          'X-Patreon-Signature': '46cedb482667457a9199117b768e05c6'
        }
      end

    end

  end

end
