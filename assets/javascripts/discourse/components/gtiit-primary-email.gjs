import { i18n } from "discourse-i18n";

export default <template>
  {{#if @email}}
    <span
      aria-label={{i18n "gtiit_primary_email.label"}}
      class="gtiit-primary-email"
      role="group"
    >
      <span class="gtiit-primary-email__address" dir="ltr">{{@email}}</span>
    </span>
  {{/if}}
</template>;
