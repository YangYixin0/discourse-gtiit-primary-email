const fs = require("fs");
const assert = require("node:assert/strict");
const {
  chromium,
} = require("/workspace/discourse/node_modules/.pnpm/playwright@1.64.0/node_modules/playwright");
const fixture = JSON.parse(fs.readFileSync("/workspace/fixture.json"));
const base = "http://localhost:3000";
const out = "/workspace/evidence";
fs.mkdirSync(out, { recursive: true });
const results = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function login(page, name) {
  await page.goto(base + "/login", {
    waitUntil: "domcontentloaded",
    timeout: 120000,
  });
  await page.locator("#login-account-name").fill(name, { timeout: 120000 });
  await page
    .locator("#login-account-password")
    .fill("Synthetic-Validation-2026!");
  await page.locator("#login-button").click();
  await sleep(5000);
  console.log(
    "LOGIN_BODY",
    name,
    (await page.locator("body").innerText()).slice(0, 2000),
  );
  await page.screenshot({ path: `${out}/login-${name}.png` });
  await page.locator("#current-user").waitFor({ timeout: 120000 });
}
async function mutate(page, path, data, method = "PUT") {
  return page.evaluate(
    async ({ path, data, method }) => {
      const c = await fetch("/session/csrf.json").then((r) => r.json());
      const r = await fetch(path, {
        method,
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": c.csrf,
          "X-Requested-With": "XMLHttpRequest",
        },
        body: JSON.stringify(data),
      });
      return { status: r.status, text: await r.text() };
    },
    { path, data, method },
  );
}
async function record(page, name, expected, scope = page) {
  const el = scope
    .locator(".gtiit-primary-email")
    .filter({ hasText: expected })
    .first();
  await el.waitFor({ timeout: 90000 });
  await sleep(800);
  const details = await el.evaluate((e) => ({
    text: e.textContent,
    box: e.getBoundingClientRect().toJSON(),
    clientWidth: e.clientWidth,
    scrollWidth: e.scrollWidth,
    viewport: innerWidth,
    overflow: document.documentElement.scrollWidth > innerWidth,
  }));
  assert(details.text.includes(expected));
  assert.equal(details.text.trim(), expected);
  assert.equal(
    await el.getAttribute("aria-label"),
    name.includes("zh_CN") ? "主邮箱" : "Primary email",
  );
  assert(
    details.box.x >= 0 && details.box.right <= details.viewport + 1,
    JSON.stringify(details),
  );
  assert(!details.overflow, "page horizontal overflow");
  assert(
    details.scrollWidth <= details.clientWidth + 1,
    "email content overflow",
  );
  await page.screenshot({ path: `${out}/${name}.png`, fullPage: false });
  results.push({ name, ...details });
  fs.writeFileSync(
    `${out}/layout-results.json`,
    JSON.stringify(results, null, 2),
  );
  console.log("PASS", name, JSON.stringify(details));
}
(async () => {
  const browser = await chromium.launch({
    headless: true,
    channel: "chromium",
    args: ["--no-sandbox"],
  });
  try {
    for (const size of ["desktop", "mobile"]) {
      const context = await browser.newContext(
        size === "mobile"
          ? {
              viewport: { width: 390, height: 844 },
              isMobile: true,
              hasTouch: true,
            }
          : { viewport: { width: 1440, height: 1000 } },
      );
      const page = await context.newPage();
      page.on("pageerror", (e) => console.log("PAGEERROR", e.message));
      await login(page, "bob");
      for (const lang of ["en", "zh_CN"]) {
        const update = await mutate(page, "/u/bob.json", { locale: lang });
        assert.equal(update.status, 200, update.text.slice(0, 300));
        await page.goto(`${base}/u/alice/summary`, {
          waitUntil: "domcontentloaded",
        });
        await record(page, `${size}-${lang}-profile`, "alice@example.test");
        await page.goto(`${base}/t/${fixture.topic_id}`, {
          waitUntil: "domcontentloaded",
        });
        await record(page, `${size}-${lang}-post`, "alice@example.test");
        await page
          .locator(".topic-post")
          .first()
          .locator('a[data-user-card="alice"]')
          .first()
          .click();
        await page.locator("#user-card").waitFor();
        await record(
          page,
          `${size}-${lang}-card`,
          "alice@example.test",
          page.locator("#user-card"),
        );
        await page.keyboard.press("Escape");
        await page.goto(`${base}/u/author1/summary`, {
          waitUntil: "domcontentloaded",
        });
        await record(
          page,
          `${size}-${lang}-long-profile`,
          "long.primary.address.for.mobile.wrapping.validation@example.test",
        );
        await page.goto(`${base}/t/${fixture.topic_id}/2`, {
          waitUntil: "domcontentloaded",
        });
        await record(
          page,
          `${size}-${lang}-long-post`,
          "long.primary.address.for.mobile.wrapping.validation@example.test",
        );
        await page
          .locator('.topic-post a[data-user-card="author1"]')
          .first()
          .click();
        await record(
          page,
          `${size}-${lang}-long-card`,
          "long.primary.address.for.mobile.wrapping.validation@example.test",
          page.locator("#user-card"),
        );
      }
      await context.close();
    }
  } catch (e) {
    console.log("FAIL", e.stack);
    throw e;
  } finally {
    await browser.close();
  }
})();
