# cms3 - a real DrDad example

A working ASP.NET Core CMS, built end to end by DrDad's `/design -> /stories -> /taskmap -> /build` loop
against a **LOCKED** design doc - Page CRUD, ASP.NET Core Identity auth, EF Core migrations, HTMX-powered
admin UI, rich-text editing with XSS sanitization, image upload. 21 stories, 82 tasks, every one closed
through `close-unit` (built, tested, committed - not asserted).

This is a **compiled build artifact**, not the source: `dotnet publish`, framework-dependent, Razor views
precompiled into `CMS.dll`. It runs standalone; it does not include the design docs, git history, or the
story-by-story record of what DrDad's gates caught along the way. See the Field Manual for that story.

## Run it

Requires the .NET 8+ runtime (already a DrDad prerequisite).

```
dotnet CMS.dll
```

Opens on `http://localhost:5000` (or set `--urls`). SQLite database is created on first run, next to the
DLL, gitignored if you're working in a clone.

**Admin login is opt-in, on purpose.** No credential ships in this artifact - set the environment variable
before running to seed an initial admin user:

```
set CMS_SEED_ADMIN_PASSWORD=<your own choice>
dotnet CMS.dll
```

Leave it unset and you get the public, read-only side only - real pages, no login. That is deliberate: an
earlier version of this project shipped with a hardcoded seed credential, and removing it (in favor of this
opt-in, name-only pattern) is exactly the kind of gap DrDad's `/assess` and `/audit` exist to catch. See the
Field Manual's field-evidence section.

## What to actually click on

- `/` - the real home page (not the default ASP.NET scaffold - that was itself a caught-and-fixed defect)
- `/account/login` - sign in (after seeding an admin, above)
- Once signed in: create a page, add rich text + an uploaded image, save, view it live, edit it, delete it -
  every one of those steps was, at some point, a real bug this project's own gates caught and closed.
