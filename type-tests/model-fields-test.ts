import { expectTypeOf } from "expect-type";
import type Post from "discourse/models/post";
import type User from "discourse/models/user";
import "../assets/javascripts/discourse/model-types";

declare const post: Post;
declare const user: User;

expectTypeOf(post.gtiit_primary_email).toEqualTypeOf<string | null | undefined>();
expectTypeOf(user.gtiit_primary_email).toEqualTypeOf<string | null | undefined>();
