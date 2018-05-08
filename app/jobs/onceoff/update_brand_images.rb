module Jobs
  module Patreon
    class UpdateBrandImages < ::Jobs::Onceoff
      OLD_IMAGE_URL = 'https://www.patreon.com/images/patreon_navigation_logo_mini_orange.png'.freeze

      def execute_onceoff(args)
        Group.where(flair_url: OLD_IMAGE_URL).find_each do |group|
          group.flair_url = ::Patreon.default_image_url
          group.save!
        end

        Badge.where(icon: OLD_IMAGE_URL).or(Badge.where(image: OLD_IMAGE_URL)).find_each do |badge|
          badge.icon = ::Patreon.default_image_url if badge.icon == OLD_IMAGE_URL
          badge.image = ::Patreon.default_image_url if badge.image == OLD_IMAGE_URL
          badge.save!
        end
      end
    end
  end
end
