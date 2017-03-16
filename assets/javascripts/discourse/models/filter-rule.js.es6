import RestModel from 'discourse/models/rest';

export default RestModel.extend({
  group_id: -1,
  reward_list: '',

  group: function() {
    var id = this.get('group_id');

    return {name: 'sarava'};
  }.property('group_id'),
});
