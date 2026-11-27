# Contributing

Bug reports, ideas and pull requests are welcome. For anything bigger than a small
fix, open an issue first so we can agree on the approach before you write code.

## How to send a change

1. Fork the repository and branch from `main`. Keep one topic per pull request.
2. Write a failing test, make it pass, then tidy the code (red, green, refactor).
3. Run `bin/ci` and make sure it passes.
4. Open a pull request that says what changed, why, and how you tested it. Add a
   screenshot for changes to pages.

## Every pull request must

**Be tested**

- **Test first.** New behavior comes with tests written before the code: model tests
  for rules and calculations, controller tests for pages, requests and access.
- **Give every bug its own test.** Reproduce the bug in a failing test, then fix it.
  The test stays, so the same bug can't come back unnoticed.
- **Keep the whole suite green.** `bin/ci` passes. Don't skip, weaken or delete a
  failing test to get there.
- **Test the edges,** not just the happy path: blank and invalid input, another
  user's records, and old data.

**Keep the code easy to change**

- **Don't repeat yourself.** Every piece of knowledge lives in one place: a label, a
  unit, a currency, a conversion factor. For example, units are defined only in
  `app/models/units.rb`, currencies only in `User::CURRENCIES`, and the money input
  only in `app/views/shared/_money_field.html.erb`.
- **Keep it simple.** Build what's needed now, not options someone might want later.
- **Keep parts independent.** Models own rules and data, controllers handle requests,
  views display. A change in one shouldn't ripple through the others.
- **Fail early and loudly.** Validate data in models, and don't silently swallow
  errors.
- **Fix broken windows.** If you notice a small problem in code you touch, fix it or
  open an issue. Keep unrelated cleanups out of the pull request.
- **Follow Rails conventions** and the style of the code around you. Prefer plain
  Rails over a new gem, and explain in the pull request why any new dependency is
  needed.
- **Name things for what they are.** Comments explain why, not what.

**Protect people's data**

- **Never lose data in a migration.** Convert existing records instead of dropping
  them, and make sure `bin/rails db:rollback` works. `bin/rails db:migrate` backs up
  the database first.
- **Store one canonical form.** Distance and volume are stored in metric and converted
  for display. Money keeps the currency it was entered in, and amounts in different
  currencies are never added together.

**Be secure**

- **Scope every query to the signed-in user,** as in `Current.user.gears.find(id)`,
  never `Gear.find(id)`. Add a test that another user's records return "not found".
- **Permit only what the user may change.** Use `params.expect` with a list of
  fields, and never permit ownership fields like `user_id`.
- **Treat all input as untrusted.** Validate it in models. Build queries with Active
  Record methods or bound parameters, never by putting input into SQL strings.
- **Let Rails escape output.** Don't use `html_safe` or `raw` on anything a user typed.
- **No inline JavaScript or styles,** and nothing loaded from other sites. The Content
  Security Policy in `config/initializers/content_security_policy.rb` blocks them. Put
  code in `app/javascript` and styles in `app/assets/stylesheets`.
- **Keep Rails' protections on:** CSRF tokens, HTTPS in production, and the rate
  limits on sign-in, sign-up and password reset.
- **Keep secrets out of git.** Use Rails credentials or environment variables, and
  don't log passwords, tokens or personal data.
- **Test authentication changes,** including wrong passwords, expired tokens and rate
  limits.
- **Keep the API locked to its token.** Every API endpoint signs in only with a token
  in the `Authorization` header, finds records through `current_user`, and checks
  write access before changing anything. Each new endpoint needs tests for: no token,
  a revoked token, a read-only token, and another user's records. See
  `test/controllers/api/v1/security_test.rb`.
- **Document every API change** in `docs/api.md`, which the app also serves to agents.
  A field that's added, renamed or removed must change there in the same pull request.
- **Pass the security scans.** `bin/ci` runs Brakeman, which checks the code for
  common Rails security mistakes, and audits the gems and JavaScript packages for
  known vulnerabilities. Fix what they find; if a warning is truly a false alarm,
  record why in the pull request.
- **Use made-up data** in fixtures, screenshots and issues, never real people's.

## Releasing a version

Versions follow [Semantic Versioning](https://semver.org/) and are listed in
[CHANGELOG.md](CHANGELOG.md). To release one:

1. Pick the number: patch (0.1.**1**) for fixes, minor (0.**2**.0) for new features,
   major (**1**.0.0) for changes that break something users or API clients rely on.
2. Change `VERSION`, and add a dated section for it at the top of `CHANGELOG.md`
   (a test fails if you forget).
3. Commit, then tag the commit: `git tag -a v0.2.0 -m "Version 0.2.0"`, and push
   with `git push --follow-tags`.

Pull requests don't change the version; it's set when a release is made.

## Reporting a bug

Open an issue with the steps to reproduce it, what you expected, what happened
instead, and your browser.

## Reporting a security problem

Don't open a public issue. Use **Report a vulnerability** on the repository's
**Security** tab, so it can be fixed before it's made public. Include the steps to
reproduce it.

These guidelines follow *The Pragmatic Programmer* by David Thomas and Andrew Hunt,
the [Rails security guide](https://guides.rubyonrails.org/security.html), and the
[OWASP Top 10](https://owasp.org/www-project-top-ten/).
