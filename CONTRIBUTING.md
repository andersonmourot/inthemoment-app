# Contributing / Developer Guide

A practical guide to building, testing, and deploying InTheMoment. For the short
list of conventions (especially for AI assistants like Cursor), see [AGENTS.md](AGENTS.md).

## Prerequisites

| To work on… | You need |
| --- | --- |
| Core library & tests | Swift 6.0.3 |
| Vapor server | Swift 6.0.3 |
| iOS app | macOS + Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| Deployment | [flyctl](https://fly.io/docs/flyctl/) + a Fly.io account |

```bash
brew install xcodegen flyctl    # macOS
```

## Repository layout

See the tree in the [README](README.md#architecture). The key idea: `Creator`,
`Event`, and `MediaItem` are defined once in `Sources/InTheMomentCore` and reused
by both the app and the server, so the client/server JSON contract can't drift.

## Day-to-day commands

```bash
# Core (runs anywhere, including Linux/CI)
swift build
swift test

# Server
cd Server
swift build
JWT_SECRET=dev DATABASE_PATH=/tmp/itm.sqlite \
  swift run InTheMomentServer serve --hostname 127.0.0.1 --port 8080

# iOS app (macOS)
xcodegen generate          # ALWAYS run after adding/removing/renaming files
open InTheMoment.xcodeproj # run the "InTheMoment" scheme on a simulator
```

> **Never hand-edit `InTheMoment.xcodeproj`** — it is generated from `project.yml`.
> Edit files on disk + `project.yml`, then `xcodegen generate`.

## Pointing the app at a local server

`AppConfig.apiBaseURL` reads the `ITM_API_BASE_URL` env var (see `.env.example`).
Set it in the Xcode scheme's environment variables to use a local server instead
of the live one.

## REST API reference

Base URL: `https://inthemoment-api.fly.dev`. All bodies/responses are JSON with
ISO-8601 dates. The contract mirrors `APIEventStore`.

### Auth

An account is either a **creator** (has a `Creator` profile, can post events) or a
**fan** (email + password only). Login works for both. `creator` is `null` for fans.

| Method | Path | Body | Returns |
| --- | --- | --- | --- |
| `POST` | `/auth/register` | `{ email, password, displayName, handle }` | `{ token, creator }` |
| `POST` | `/auth/register-fan` | `{ email, password }` | `{ token, creator: null }` |
| `POST` | `/auth/login` | `{ email, password }` | `{ token, creator? }` |
| `GET` | `/auth/me` | — (Bearer token) | `{ email, creator? }` |

### Fan preferences (favorites & follows)

Per-account, so they sync across devices. All require `Authorization: Bearer <token>`
and act on the token's user. Each mutating call returns the updated `FanPreferences`
(`{ favoriteEventIDs: [uuid], followedCreatorIDs: [uuid] }`).

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/me/preferences` | current favorites + follows |
| `PUT` | `/me/preferences` | union-merge a `FanPreferences` body (used on first sign-in) |
| `POST` · `DELETE` | `/me/favorites/{eventId}` | add / remove a favorite |
| `POST` · `DELETE` | `/me/follows/{creatorId}` | follow / unfollow |

### Events & media

Reads are public. Writes require `Authorization: Bearer <token>` and you may only
modify events owned by your creator.

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| `GET` | `/events?published=true&creator={uuid}` | public | filters optional |
| `GET` | `/events/{id}` | public | 404 if missing |
| `POST` | `/events` | required | attributed to your creator |
| `PUT` | `/events/{id}` | required (owner) | replaces media set |
| `DELETE` | `/events/{id}` | required (owner) | |
| `POST` | `/events/{id}/media` | required (owner) | add one `MediaItem` |
| `DELETE` | `/events/{id}/media/{mediaId}` | required (owner) | |
| `GET` | `/creators` · `/creators/{id}` | public | |
| `PUT` | `/creators/{id}` | required (self) | |
| `GET` | `/health` | public | `{ "status": "ok" }` |

Errors use Vapor's envelope: `{ "error": true, "reason": "…" }`.

## Deployment (Fly.io)

The server is containerized (`Dockerfile`, multi-stage, static Swift stdlib) and
configured by `fly.toml` (app `inthemoment-api`, region `iad`, 1 GB volume mounted
at `/data`).

```bash
flyctl secrets set JWT_SECRET=$(openssl rand -hex 32) --app inthemoment-api
flyctl deploy --remote-only --app inthemoment-api
flyctl logs --app inthemoment-api
```

> A `error releasing builder: deadline_exceeded` message at the end of a deploy is
> a known non-fatal Fly warning — the image still pushes and the machine updates.

## CI

`.github/workflows/ci.yml` runs on every push/PR:

- **core-linux** — `swift build` + `swift test` for `InTheMomentCore`.
- **server-linux** — `swift build` for the `Server` package.

The iOS app is not built in CI (needs Apple's SDK); verify it in Xcode.

## Testing notes

- Core logic and the network/auth clients are unit-tested with a mock
  `HTTPTransport` (no real network). Add tests alongside new core behavior.
- Keep `Sources/InTheMomentCore` free of platform frameworks so it keeps building
  on Linux/CI.
