const fs = require("fs");
const assert = require("node:assert/strict");
const {
  chromium,
} = require("/workspace/discourse/node_modules/.pnpm/playwright@1.64.0/node_modules/playwright");
const fixture = JSON.parse(fs.readFileSync("/workspace/fixture.json"));
const base = "http://localhost:3000",
  out = "/workspace/evidence";
const results = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
function check(name, ok, detail = {}) {
  results.push({ name, pass: !!ok, detail });
  fs.writeFileSync(
    out + "/email-results.json",
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
  await p.locator("#current-user").waitFor();
}
async function snapshot(viewer, name, email) {
  await viewer.goto(`${base}/t/${fixture.topic_id}/1`);
  const first = viewer.locator("#post_1 .gtiit-primary-email");
  await first.waitFor();
  check(name + " old post", (await first.innerText()).includes(email));
  const data = await viewer.evaluate(async (id) => {
    const options = {
      headers: {
        Accept: "application/json",
        "X-Requested-With": "XMLHttpRequest",
      },
    };
    const [u, c, t] = await Promise.all([
      fetch("/u/alice.json", options).then((r) => r.json()),
      fetch("/u/alice/card.json", options).then((r) => r.json()),
      fetch(`/t/${id}.json`, options).then((r) => r.json()),
    ]);
    return {
      profile: u.user.gtiit_primary_email,
      card: c.user.gtiit_primary_email,
      post: t.post_stream.posts.find((p) => p.post_number === 1)
        .gtiit_primary_email,
      all: JSON.stringify([u, c, t]).includes("alice.secondary@example.test"),
    };
  }, fixture.topic_id);
  check(
    name + " serialization",
    [data.profile, data.card, data.post].every((x) => x === email) && !data.all,
    data,
  );
  await viewer.screenshot({ path: `${out}/${name}.png` });
}
async function emailLink(kind) {
  for (let i = 0; i < 60; i++) {
    const list = await fetch("http://localhost:8025/api/v1/messages").then(
      (r) => r.json(),
    );
    for (const m of list.messages || []) {
      const mail = await fetch(
        "http://localhost:8025/api/v1/message/" + m.ID,
      ).then((r) => r.json());
      const text = (mail.Text || "") + " " + (mail.HTML || "");
      const re = new RegExp(
        'https?://[^\\s"<>]+/u/confirm-' + kind + '-email/[^\\s"<>]+',
      );
      const match = text.match(re);
      if (match) return match[0].replace(/&amp;/g, "&").replace(/[).,]+$/, "");
    }
    await sleep(1000);
  }
  throw Error("No synthetic " + kind + " confirmation mail captured");
}
(async () => {
  const b = await chromium.launch({
    channel: "chromium",
    headless: true,
    args: ["--no-sandbox"],
  });
  const ca = await b.newContext({ viewport: { width: 1440, height: 1000 } }),
    cv = await b.newContext({ viewport: { width: 1440, height: 1000 } });
  const a = await ca.newPage(),
    v = await cv.newPage();
  try {
    await login(a, "alice");
    await login(v, "bob");
    await fetch("http://localhost:8025/api/v1/messages", { method: "DELETE" });
    await snapshot(v, "email-before-confirmation", "alice@example.test");
    await a.goto(base + "/u/alice/preferences/email");
    await a.locator("#change-email").fill("alice.changed@example.test");
    await a.locator('.save-button button[type="submit"]').click();
    await a.locator(".alert-success").waitFor();
    await a.screenshot({ path: out + "/email-change-requested.png" });
    await snapshot(v, "email-pending-old-confirmation", "alice@example.test");
    const oldLink = await emailLink("old");
    await a.goto(oldLink);
    await a.locator(".confirm-old-email .btn-primary").click();
    await a.locator(".dialog-footer .btn-primary").click();
    await a.locator(".confirm-old-email").waitFor({ state: "hidden" });
    await snapshot(v, "email-pending-new-confirmation", "alice@example.test");
    const newLink = await emailLink("new");
    await a.goto(newLink);
    await a.locator(".confirm-new-email .btn-primary").click();
    await a.locator(".dialog-footer .btn-primary").click();
    await a.locator(".confirm-new-email").waitFor({ state: "hidden" });
    await snapshot(v, "email-after-confirmation", "alice.changed@example.test");
    check("two-stage UI mail confirmation complete", true);
    // The original post still exists; the displayed address comes from its author now.
    await v.goto(base + "/u/alice/summary");
    check(
      "fresh full profile updated",
      (await v.locator(".gtiit-primary-email").innerText()).includes(
        "alice.changed@example.test",
      ),
    );
    await v.screenshot({ path: out + "/email-updated-profile.png" });
    await v.goto(`${base}/t/${fixture.topic_id}`);
    await v.locator('.topic-post a[data-user-card="alice"]').first().click();
    await v.locator("#user-card .gtiit-primary-email").waitFor();
    check(
      "fresh user card updated",
      (await v.locator("#user-card .gtiit-primary-email").innerText()).includes(
        "alice.changed@example.test",
      ),
    );
    await v.screenshot({ path: out + "/email-updated-card.png" });
  } catch (e) {
    console.log("FAIL", e.message);
    await a.screenshot({ path: out + "/email-failure.png" });
    console.log("UI", (await a.locator("body").innerText()).slice(0, 2500));
    throw e;
  } finally {
    await b.close();
  }
})();
