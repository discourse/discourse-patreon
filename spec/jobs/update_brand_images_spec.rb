# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::Patreon::UpdateBrandImages do

  let(:old_image_url) { Jobs::Patreon::UpdateBrandImages::OLD_IMAGE_URL }
  let(:new_image_url) { ::Patreon.default_image_url }

  it 'should update to old image url to new local path' do
    group = Fabricate(:group, flair_url: old_image_url)
    badge = Fabricate(:badge, icon: old_image_url, image: old_image_url)

    described_class.new.execute_onceoff({})

    group.reload
    expect(group.flair_url).to eq(new_image_url)

    badge.reload
    expect(badge.icon).to eq(new_image_url)
    expect(badge.image).to eq(new_image_url)
  end

end
