require 'openssl'

class ::Patreon::PatreonWebhookController < ActionController::Base

  TRIGGERS = ['pledges:create', 'pledges:update', 'pledges:delete']

  def index

    raise Discourse::InvalidAccess.new unless TRIGGERS.include? headers['X-Patreon-Event']

    raise Discourse::InvalidAccess.new unless valid_signature?(headers, params)


    byebug

    Jobs.enqueue(:sync_patrons_to_groups)

    render nothing: true, status: 200
  end

  private

  def valid_signature?(headers, params)
    digest = OpenSSL::Digest::MD5.new
    data = params[:data]
    signature = headers['X-Patreon-Signature']
    signature == OpenSSL::HMAC.hexdigest(digest, SiteSetting.patreon_client_secret, data)
  end
end