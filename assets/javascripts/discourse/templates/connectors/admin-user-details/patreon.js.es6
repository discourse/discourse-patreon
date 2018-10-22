export default {
  setupComponent(args, component) {
    const email = args.model.patreon_email;
    let url = "https://patreon.com/members";

    if (email) {
      url = `${url}?query=${email}`;
    }

    component.set("patron_url", url);
  },

  shouldRender(args, component) {
    return component.siteSettings.patreon_enabled && args.model.patreon_id;
  }
};
