const fs = require("fs"),
  assert = require("node:assert/strict");
const {
  chromium,
} = require("/workspace/discourse/node_modules/.pnpm/playwright@1.64.0/node_modules/playwright");
const fixture = JSON.parse(fs.readFileSync("/workspace/fixture.json")),
  base = "http://localhost:3000",
  out = "/workspace/evidence";
const results = [];
function check(name, ok, detail = {}) {
  results.push({ name, pass: !!ok, detail });
  fs.writeFileSync(
    out + "/session-results.json",
    JSON.stringify(results, null, 2),
  );
  console.log(ok ? "PASS" : "FAIL", name, JSON.stringify(detail));
  assert(ok, name);
}
async function login(p, name) {
  await p.goto(base + "/login");
  await p.locator("#login-account-name").fill(name);
  await p.locator("#login-account-password").fill("Synthetic-Validation-2026!");
  await p.locator("#login-button").click();
  try {
    await p.locator("#current-user").waitFor();
  } catch (e) {
    console.log(
      "LOGIN_UI",
      (await p.locator("body").innerText()).slice(0, 2500),
    );
    throw e;
  }
}
async function data(p) {
  return p.evaluate(async (id) => {
    const options = {
      headers: {
        Accept: "application/json",
        "X-Requested-With": "XMLHttpRequest",
      },
    };
    const urls = ["/u/alice.json", "/u/alice/card.json", `/t/${id}.json`];
    return Promise.all(
      urls.map(async (url) => {
        const r = await fetch(url, options),
          d = await r.json();
        return {
          url,
          status: r.status,
          fields:
            JSON.stringify(d).match(/"gtiit_primary_email":/g)?.length || 0,
          cache: r.headers.get("cache-control"),
        };
      }),
    );
  }, fixture.topic_id);
}
(async () => {
  const b = await chromium.launch({
    channel: "chromium",
    headless: true,
    args: ["--no-sandbox"],
  });
  const c = await b.newContext(),
    p = await c.newPage();
  try {
    await login(p, "bob");
    check(
      "member before logout",
      (await data(p)).every((x) => x.fields > 0),
    );
    const logout = await p.evaluate(async () => {
      const c = await fetch("/session/csrf.json").then((r) => r.json());
      return (
        await fetch("/session/bob", {
          method: "DELETE",
          headers: {
            "X-CSRF-Token": c.csrf,
            "X-Requested-With": "XMLHttpRequest",
          },
        })
      ).status;
    });
    check("logout request", logout === 200);
    await p.goto(base + "/u/alice/summary");
    await p.locator(".user-main").waitFor();
    check(
      "anonymous fresh profile DOM",
      (await p.locator(".gtiit-primary-email").count()) === 0,
    );
    check(
      "same browser anonymous JSON",
      (await data(p)).every((x) => x.status === 200 && x.fields === 0),
    );
    await p.screenshot({ path: out + "/anonymous-profile.png" });
    await p.goto(`${base}/t/${fixture.topic_id}`);
    await p.locator("#post_1").waitFor();
    check(
      "anonymous topic DOM",
      (await p.locator(".gtiit-primary-email").count()) === 0,
    );
    await p.screenshot({ path: out + "/anonymous-topic.png" });
    await login(p, "alice");
    const after = await data(p);
    check(
      "same browser login as another member",
      after.every(
        (x) =>
          x.status === 200 &&
          x.fields > 0 &&
          x.cache.includes("private") &&
          x.cache.includes("no-store"),
      ),
      after,
    );
    await p.goto(`${base}/t/${fixture.topic_id}`);
    await p.locator("#post_1 .gtiit-primary-email").waitFor();
    check(
      "second member updated old post",
      (await p.locator("#post_1 .gtiit-primary-email").innerText()).includes(
        "alice.changed@example.test",
      ),
    );
    await p.screenshot({ path: out + "/second-member-after-login.png" });
  } finally {
    await b.close();
  }
})();
