import FilterRule from 'discourse/plugins/discourse-patreon/discourse/models/filter-rule';
import { ajax } from 'discourse/lib/ajax';

export default Discourse.Route.extend({
  model() {
    return ajax("/patreon/list.json")
    .then(function(result) {
      var final = result.slack;

      return final.map(function(v) {
        return FilterRule.create(v);
      });
    });
  }
});
