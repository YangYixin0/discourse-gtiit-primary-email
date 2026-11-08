import { i18n } from "discourse-i18n";

export default <template>
  {{#if @email}}
    <span class="gtiit-primary-email">
      <span class="gtiit-primary-email__label">{{i18n
          "gtiit_primary_email.label"
        }}:</span>
      <span class="gtiit-primary-email__address" dir="ltr">{{@email}}</span>
    </span>
  {{/if}}
</template>;
