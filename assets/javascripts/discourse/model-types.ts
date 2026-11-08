import "discourse/models/post";
import "discourse/models/user";

declare module "discourse/models/post" {
  interface PostFields {
    gtiit_primary_email?: string | null;
  }
}

declare module "discourse/models/user" {
  interface UserFields {
    gtiit_primary_email?: string | null;
  }
}
