import Group from "discourse/models/group";
import { ajax } from "discourse/lib/ajax";
import FilterRule from "discourse/plugins/discourse-patreon/discourse/models/filter-rule";

/* We use three main model to get this page working:
 *  Discourse Groups (excluding the automatic ones), Patreon rewards and
 *  and current filters (one filter is a tuple between 1 Discourse group and N Patreon rewards)
 */
export default Discourse.Route.extend({
  model() {
    return Ember.RSVP.Promise.all([
      ajax("/patreon/list.json"),
      Group.findAll({ ignore_automatic: true })
    ]).then(([result, groups]) => {
      groups = groups.map(g => {
        return { id: g.id, name: g.name };
      });

      return {
        filters: result.filters,
        plans: result.plans,
        last_sync_at: result.last_sync_at,
        groups: groups
      };
    });
  },

  setupController: function(controller, model) {
    const plans = model.plans;
    const groups = model.groups;
    const filtersArray = _.map(model.filters, (v, k) => {
      const planNames = v.map(r => {
        const plan = plans.findBy("id", parseInt(r));
        return plan ? `$${plan.amount} - ${plan.name}` : "";
      });
      const group = _.find(groups, g => g.id === parseInt(k, 10));

      return FilterRule.create({
        group: group.name,
        plans: planNames,
        group_id: k,
        plan_ids: v
      });
    });

    controller.setProperties({
      model: filtersArray,
      groups: groups,
      plans: plans,
      last_sync_at: model.last_sync_at
    });
  }
});
