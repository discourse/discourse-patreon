import { ajax } from 'discourse/lib/ajax';

export default Discourse.Route.extend({
  model() {

    return Promise.all([ajax("/patreon/list.json"), ajax("/patreon/rewards.json"), ajax("/admin/groups.json")])
                  .then(([filters_result, rewards_result, groups_result]) => {
                    return {filters: filters_result, rewards: rewards_result, groups: groups_result};
                  });
  }
});
