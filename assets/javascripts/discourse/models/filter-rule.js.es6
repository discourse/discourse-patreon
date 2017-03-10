import RestModel from 'discourse/models/rest';

export default RestModel.extend({
  category_id: -1,
  channel: '',
  filter: null,

  category: function() {
    var id = this.get('category_id');

    if (id === "0")
      return Discourse.Category.create({ name: 'All Categories', id: 0 });
    else {
      return Discourse.Category.findById(id) || { id: id, name: 'Deleted Category' };
    }
  }.property('category_id'),

  filter_name: function() {
    return I18n.t('slack.present.' + this.get('filter') );
  }.property('filter')

});
