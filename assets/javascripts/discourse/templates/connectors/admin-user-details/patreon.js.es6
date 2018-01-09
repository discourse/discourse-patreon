export default {
  shouldRender(args, component) {
     return component.siteSettings.patreon_enabled && args.model.patreon_id;
  }
};
