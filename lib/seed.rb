# frozen_string_literal: true

module ::Patreon
  class Seed

    def self.seed_content!
      return if GroupCustomField.exists?(name: "default_patreon_group")

      default_group = Group.where(name: 'patrons').first_or_initialize(
        visibility_level: Group.visibility_levels[:public],
        primary_group: true,
        title: 'Patron',
        flair_url: ::Patreon.default_image_url,
        bio_raw: 'To get access to this group go to our [Patreon page](https://www.patreon.com/) and add your pledge.',
        full_name: 'Our Patreon supporters'
      )
      default_group.custom_fields["default_patreon_group"] = true
      default_group.save!

      badge = Badge.where(name: 'Patron').first_or_initialize(
        description: 'Active Patron',
        badge_type_id: 1,
        icon: ::Patreon.default_image_url,
        listable: true,
        target_posts: false,
        query: "select user_id, created_at granted_at, NULL post_id from group_users where group_id = ( select g.id from groups g where g.name = 'patrons' )",
        enabled: true,
        auto_revoke: true,
        badge_grouping_id: 2,
        trigger: 0,
        show_posts: false,
        system: false,
        image: ::Patreon.default_image_url,
        long_description: 'To get access to this badge go to our <a href="https://www.patreon.com/">Patreon page</a> and add your pledge.'
      )
      badge.save!

    end
  end
end
