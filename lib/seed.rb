module ::Patreon
  class Seed
    PLUGIN_NAME = 'discourse-patreon'.freeze

    def self.seed_content!

      default_group = Group.new(
        name: 'patrons',
        visibility_level: Group.visibility_levels[:public],
        primary_group: true,
        title: 'Patron',
        flair_url: ::Patreon::DEFAULT_IMAGE_URL,
        bio_raw: 'To get access to this group go to our [Patreon page](https://www.patreon.com/) and add your pledge.',
        full_name: 'Our Patreon supporters'
      )
      default_group.save!

      badge = Badge.new(
        name: 'Patron',
        description: 'Active Patron',
        badge_type_id: 1,
        icon: ::Patreon::DEFAULT_IMAGE_URL,
        listable: true,
        target_posts: false,
        query: "select user_id, created_at granted_at, NULL post_id from group_users where group_id = ( select g.id from groups g where g.name = 'patrons' )",
        enabled: true,
        auto_revoke: true,
        badge_grouping_id: 2,
        trigger: 0,
        show_posts: false,
        system: false,
        image: ::Patreon::DEFAULT_IMAGE_URL,
        long_description: 'To get access to this badge go to our <a href="https://www.patreon.com/">Patreon page</a> and add your pledge.'
      )
      badge.save!

      basic_filter = { default_group.id.to_s => ['0'] }
      ::PluginStore.set(PLUGIN_NAME, 'filters', basic_filter)

    end
  end
end
