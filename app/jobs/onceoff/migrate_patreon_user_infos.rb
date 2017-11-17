module Jobs
  module Patreon
    class MigratePatreonUserInfos < ::Jobs::Onceoff

      def execute_onceoff(args)
        rows = PluginStoreRow.where(plugin_name: ::Patreon::PLUGIN_NAME).where("key ~* :pat", :pat => '^login_user_')
        rows.each do |row|
          user_id = row.key.gsub('login_user_', '')

          begin
            Oauth2UserInfo.create(
              uid: eval(row.value)[:patreon_id],
              provider: "patreon",
              user_id: user_id
            )
          rescue ActiveRecord::RecordNotUnique => e
            # record already migrated
          end
        end
      end
    end
  end
end
