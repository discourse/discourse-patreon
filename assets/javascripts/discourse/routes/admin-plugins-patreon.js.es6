import { ajax } from 'discourse/lib/ajax';
import FilterRule from 'discourse/plugins/discourse-slack-official/discourse/models/filter-rule';


export default Discourse.Route.extend({
  model() {

    return Promise.all([ajax("/patreon/list.json"), ajax("/patreon/rewards.json"), ajax("/admin/groups.json")])
                  .then(([filters_result, rewards_result, groups_result]) => {
                    return {filters: filters_result, rewards: rewards_result, groups: groups_result};
                  });
  },

  setupController: function(controller, model) {

    const filtersArray = _.map(model.filters, (v, k) => {
      const rewardsNames = v.map((r) => ` $${model.rewards[r].amount_cents} - ${model.rewards[r].title}`);
      const group =_.find(model.groups, (g) => g.id === parseInt(k));

      return FilterRule.create({group: group.name, rewards: rewardsNames, group_id: k, reward_ids: v});
    });

    const automaticGroups = model.groups.reject((g) => g.automatic);

    controller.setProperties({ model: filtersArray, groups: automaticGroups, rewards: model.rewards });
  }
});
