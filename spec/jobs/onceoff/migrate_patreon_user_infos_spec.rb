require 'rails_helper'

RSpec.describe Jobs::Patreon::MigratePatreonUserInfos do

  let(:user) { Fabricate(:user) }

  it "should copy user's patreon id from `PluginStore` to `Oauth2UserInfo`" do
    patreon_id = 7
    ::PluginStore.set(::Patreon::PLUGIN_NAME, "login_user_#{user.id}", patreon_id: patreon_id)

    described_class.new.execute_onceoff({})

    expect(Oauth2UserInfo.find_by(uid: patreon_id, provider: "patreon").user_id).to eq(user.id)
  end

end
