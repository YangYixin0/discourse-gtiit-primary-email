import { apiInitializer } from "discourse/lib/api";
import PrimaryEmail from "../components/gtiit-primary-email.gjs";

export default apiInitializer((api) => {
  api.addTrackedPostProperties("gtiit_primary_email");
  api.renderInOutlet(
    "user-card-post-names",
    <template><PrimaryEmail @email={{@user.gtiit_primary_email}} /></template>
  );
  api.renderInOutlet(
    "user-profile-primary",
    <template><PrimaryEmail @email={{@model.gtiit_primary_email}} /></template>
  );
  api.renderAfterWrapperOutlet(
    "post-meta-data-poster-name",
    <template><PrimaryEmail @email={{@post.gtiit_primary_email}} /></template>
  );
});
