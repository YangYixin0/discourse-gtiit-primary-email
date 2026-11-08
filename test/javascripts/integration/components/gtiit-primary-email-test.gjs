import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PrimaryEmail from "discourse/plugins/discourse-gtiit-primary-email/discourse/components/gtiit-primary-email";

module("Integration | Component | GTIIT primary email", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the address as escaped text", async function (assert) {
    const email = "<img src=x onerror=alert(1)>@gtiit.example";

    await render(<template><PrimaryEmail @email={{email}} /></template>);

    assert.dom(".gtiit-primary-email__address").hasText(email);
    assert.dom(".gtiit-primary-email img").doesNotExist();
  });

  test("omits the display when the server withheld the field", async function (assert) {
    await render(<template><PrimaryEmail /></template>);

    assert.dom(".gtiit-primary-email").doesNotExist();
  });
});
