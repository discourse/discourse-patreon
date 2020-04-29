import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";

export default {
  shouldRender(args, component) {
    component.args.subscription = args.model.subscription;
    component.args.patron_url = "https://patreon.com/members";
    return component.siteSettings.patreon_enabled && args.model.subscription;
  },

  actions: {
    checkPatreonEmail(user) {
      ajax(userPath(`${user.username_lower}/patreon_email.json`), {
        data: { context: window.location.pathname }
      }).then(result => {
        if (result) {
          const email = result.email;
          let url = "https://patreon.com/members";

          if (email) {
            url = `${url}?query=${email}`;
          }

          this.set("patreon_email", email);
          this.set("patron_url", url);
        }
      });
    }
  }
};
