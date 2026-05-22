# Backend Design — Now Playing

**Status:** Draft for review. Nothing here is built yet.
**Scope:** Sketch of (1) DynamoDB single-table schema for cross-device waypoint sync, (2) authentication flow between the iOS/watchOS clients and the backend, (3) the eventual Spotify Web API broker path.

---

## 1. Guiding decisions (validate these first)

These are the load-bearing assumptions everything below rests on. If any of these are wrong, the design changes.

| # | Decision | Default chosen | Why |
|---|---|---|---|
| D1 | Primary user identity | **Sign In with Apple** | Stable across Spotify re-auths, free, no PII storage burden, App Store-friendly. Spotify is *linked* to the identity, not the identity itself. |
| D2 | Data model shape | **DynamoDB single-table** | Fits the small, fixed set of access patterns. Cheap, scales, no joins needed. |
| D3 | Conflict resolution | **Last-write-wins** (per waypoint, on `updated_at`) | Simpler than vector clocks / CRDTs. Acceptable because waypoints are user-authored and rarely edited from two devices simultaneously. |
| D4 | Token strategy | **App-issued JWT** (short-lived) + opaque refresh token | Avoids per-request round-trips to Apple. Backend signs JWTs with a KMS-managed key. |
| D5 | Spotify Web API access | **Deferred** — not built until a concrete feature needs it (likely BPM/audio features) | Avoids storing refresh tokens before we have to. |
| D6 | API framework | **TBD** — FastAPI + Mangum, AWS Lambda Powertools, or plain handlers | Decide after first endpoint is written by hand. |

---

## 2. Access patterns

The single-table design has to satisfy these patterns and nothing else (yet). If a future feature needs a pattern not on this list, revisit the schema before building it.

| # | Pattern | Frequency | Implementation |
|---|---|---|---|
| AP1 | Get all waypoints for user `U` on track `T` | **Hot path** — every time a user opens a track | `Query` PK=`USER#<sub>`, SK `begins_with WAYPOINT#<track_uri>#` |
| AP2 | Create / update a single waypoint | Hot path — every edit | `PutItem` with conditional expression on `version` |
| AP3 | Delete a single waypoint | Hot path | `DeleteItem` by PK+SK |
| AP4 | Get all waypoints for user `U` (export/migration) | Rare | `Query` PK=`USER#<sub>`, SK `begins_with WAYPOINT#` |
| AP5 | Get user profile | Per session, on app launch | `GetItem` PK=`USER#<sub>`, SK=`PROFILE` |
| AP6 | (Future) Get Spotify linkage / refresh token for user | Per Web API call from backend | `GetItem` PK=`USER#<sub>`, SK=`SPOTIFY_LINK` |
| AP7 | (Future) Find user by Spotify user ID (e.g. for sharing waypoints) | Rare | GSI1, only added when needed |

**Explicitly not supported (yet):**
- "Which users have waypoints on track X?" — would need a GSI on track URI. Not adding until a social/sharing feature requires it.
- Analytics queries ("most-waypointed tracks") — those run on a separate analytics path (e.g., DynamoDB Streams → S3 → Athena), not on the OLTP table.

---

## 3. DynamoDB schema

**Table name:** `nowplaying` (one table for everything)

**Billing:** On-demand. Indie traffic is unpredictable and bursty; provisioned capacity is wrong here.

**Keys:**

| Attribute | Type | Role |
|---|---|---|
| `pk` | String (HASH) | Partition key — almost always `USER#<apple_sub>` |
| `sk` | String (RANGE) | Sort key — determines item type and supports `begins_with` queries |

### Item shapes

Every item lives in the same table under the same `pk` (the user). The `sk` prefix distinguishes the entity type.

#### Profile item (one per user)

```
pk:           USER#001234.abc...xyz    (Apple sub)
sk:           PROFILE
type:         "profile"
created_at:   "2026-05-22T18:00:00Z"
updated_at:   "2026-05-22T18:00:00Z"
display_name: "Brandon"                (optional, from Apple if user shared it)
email:        "abc@privaterelay.apple..." (optional, Apple anonymous relay)
```

#### Waypoint item (many per user, keyed by track URI)

```
pk:               USER#001234.abc...xyz
sk:               WAYPOINT#spotify:track:6rqhFgbbKwnb9MLmUQDhG6#3f8c2b91-...
type:             "waypoint"
track_uri:        "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"
waypoint_id:      "3f8c2b91-1c33-4f2b-9c80-a7d4..."     (UUID, generated client-side)
position_seconds: 47
color_hex:        "#FF5A5F"
created_at:       "2026-05-22T18:00:00Z"
updated_at:       "2026-05-22T18:00:00Z"
version:          1                                       (for optimistic concurrency)
```

**Why client-generated UUIDs?** The iOS app already creates `Waypoint(id: UUID())` in `Waypoint.swift`. Keeping client-generated IDs means offline-created waypoints sync without ID reconciliation.

**Why `version`?** Enables `ConditionExpression: version = :expected_version` on update, so a stale device can't silently overwrite a newer edit from another device. On conflict, the client refetches and re-merges.

#### Spotify linkage item (future — only if/when we add Web API broker)

```
pk:                    USER#001234.abc...xyz
sk:                    SPOTIFY_LINK
type:                  "spotify_link"
spotify_user_id:       "brandon_lc"
refresh_token_encrypted: <base64 of KMS-encrypted refresh token>
scopes:                ["user-read-playback-state", "user-read-currently-playing", ...]
expires_at:            "2026-08-22T18:00:00Z"             (refresh token expiry; Spotify refresh tokens currently don't expire but treat them as if they do)
created_at:            "2026-05-22T18:00:00Z"
updated_at:            "2026-05-22T18:00:00Z"
```

**Encryption:** Use AWS KMS with a customer-managed key, not the default AWS-owned key. KMS-encrypt the refresh token at the application layer before storing it. DynamoDB's at-rest encryption alone is not enough — that protects against disk-level compromise, not against accidental exposure of table contents via misconfigured IAM or logging.

### TTL

No TTL on user data. Add TTL later for ephemeral items (e.g., refresh-token blacklist entries, OAuth state nonces) if those ever land in this table.

### Indexes

**No GSIs at launch.** All current access patterns are satisfied by the base table.

When AP7 (find user by Spotify ID) becomes needed:

| Index | PK | SK | Purpose |
|---|---|---|---|
| `GSI1` | `gsi1pk` = `SPOTIFY#<spotify_user_id>` | `gsi1sk` = `USER#<apple_sub>` | Lookup user by linked Spotify account |

Adding GSI1 only requires backfilling existing `SPOTIFY_LINK` items with the `gsi1pk` / `gsi1sk` attributes — no schema migration, no downtime.

### Capacity & cost sanity check

For one user with ~50 tracks × 5 waypoints = 250 items, plus ~5 daily edits and ~20 daily reads:
- **Storage:** ~50 KB. Free tier covers 25 GB.
- **Reads/writes:** Trivially under the 25 RCU/WCU free tier even on-demand.
- **Expected monthly cost:** $0. Stays $0 well into hundreds of users.

---

## 4. Authentication flow

### Identity model

Two **independent** OAuth flows, two **independent** token lifetimes:

```
                  ┌─────────────────────────┐
                  │   Apple ID (identity)   │  ←─ who the user IS
                  │   Sign In with Apple    │     stable, long-lived
                  └────────────┬────────────┘
                               │
                               │ provides app's user_id (apple sub)
                               ▼
                  ┌─────────────────────────┐
                  │   Now Playing backend   │
                  │   - waypoints           │
                  │   - settings            │
                  │   - (future) Web API    │
                  └────────────┬────────────┘
                               │
                               │ user optionally LINKS
                               ▼
                  ┌─────────────────────────┐
                  │   Spotify (capability)  │  ←─ what the user can DO
                  │   App Remote SDK +      │     swappable, can re-link
                  │   (future) Web API      │
                  └─────────────────────────┘
```

The crucial point: a user can sign out of Spotify and back in (or even switch Spotify accounts entirely) without losing their waypoints. The waypoints belong to the Apple identity, not the Spotify identity.

### Flow A — Initial sign-in (Sign In with Apple → app JWT)

```
iOS app                    Backend (Lambda)              Apple identity service
  │                              │                              │
  │ 1. User taps "Sign In w/ Apple"                             │
  │ ───────────────────────────────────────────────────────────▶│
  │                              │                              │
  │ 2. Apple returns identityToken (JWT signed by Apple)        │
  │ ◀───────────────────────────────────────────────────────────│
  │                              │                              │
  │ 3. POST /auth/apple          │                              │
  │    { identity_token,         │                              │
  │      authorization_code,     │                              │
  │      nonce }                 │                              │
  │ ────────────────────────────▶│                              │
  │                              │                              │
  │                              │ 4. Fetch Apple JWKS (cached) │
  │                              │ ────────────────────────────▶│
  │                              │ ◀────────────────────────────│
  │                              │                              │
  │                              │ 5. Verify JWT signature,     │
  │                              │    issuer, audience, nonce,  │
  │                              │    exp                       │
  │                              │                              │
  │                              │ 6. Extract `sub` (stable      │
  │                              │    Apple user ID)            │
  │                              │                              │
  │                              │ 7. Upsert USER#<sub>/PROFILE │
  │                              │    in DynamoDB               │
  │                              │                              │
  │                              │ 8. Mint app JWT (15 min TTL) │
  │                              │    + refresh token (90d)     │
  │                              │    signed with KMS key       │
  │                              │                              │
  │ 9. { access_token,           │                              │
  │      refresh_token }         │                              │
  │ ◀────────────────────────────│                              │
  │                              │                              │
  │ 10. Store both in Keychain   │                              │
```

**JWT claims** (app-issued):

```json
{
  "iss": "nowplaying.app",
  "sub": "001234.abc...xyz",          // Apple sub, our canonical user_id
  "iat": 1747936800,
  "exp": 1747937700,
  "scope": "waypoints:rw"
}
```

**Why app-issued JWTs and not "pass the Apple token every time"?**
- Apple `identityToken` lifetimes are short and not designed to be a session token.
- Verifying our own JWT signature is one local crypto op; verifying Apple's requires JWKS lookup (cacheable, but still a moving part).
- Refresh token rotation is fully under our control.

### Flow B — Authenticated request (the hot path)

```
iOS app                    Backend (Lambda + API GW)
  │                              │
  │ GET /waypoints?track=spotify:track:...
  │ Authorization: Bearer <app_jwt>
  │ ────────────────────────────▶│
  │                              │
  │                              │ 1. Lambda authorizer:
  │                              │    - Verify JWT signature
  │                              │      (KMS public key, cached)
  │                              │    - Check exp
  │                              │    - Extract sub → user_id
  │                              │
  │                              │ 2. Handler:
  │                              │    DynamoDB Query
  │                              │    pk = USER#<user_id>
  │                              │    sk begins_with WAYPOINT#<track_uri>#
  │                              │
  │ 200 [{...}, {...}, ...]      │
  │ ◀────────────────────────────│
```

Use **API Gateway Lambda Authorizer** (TOKEN type) with a 5-minute TTL cache. The authorizer Lambda is separate from the handler Lambda — keeps the handler cold-start path narrow.

### Flow C — Refresh

Standard OAuth2 refresh-token flow. Client posts refresh token to `/auth/refresh`; backend validates against the stored refresh-token record in DynamoDB (PK=`USER#<sub>`, SK=`REFRESH#<token_hash>`), rotates it (issues a new refresh token, invalidates the old), and returns a new access token. Store only the *hash* of the refresh token in DynamoDB, never the token itself.

### Flow D — Spotify linkage (future, when Web API broker is built)

Authorization Code flow with **PKCE**, so the iOS app never needs the Spotify `client_secret`:

```
iOS app                    Backend                       Spotify
  │                              │                              │
  │ 1. Generate code_verifier    │                              │
  │    + code_challenge (S256)   │                              │
  │                              │                              │
  │ 2. ASWebAuthenticationSession to Spotify /authorize          │
  │    with code_challenge                                       │
  │ ────────────────────────────────────────────────────────────▶│
  │                              │                              │
  │ 3. authorization_code        │                              │
  │ ◀────────────────────────────────────────────────────────────│
  │                              │                              │
  │ 4. POST /spotify/link        │                              │
  │    Authorization: Bearer <app_jwt>
  │    { code, code_verifier }   │                              │
  │ ────────────────────────────▶│                              │
  │                              │                              │
  │                              │ 5. POST Spotify /api/token   │
  │                              │    with client_secret        │
  │                              │    (from Secrets Manager),   │
  │                              │    code, code_verifier       │
  │                              │ ────────────────────────────▶│
  │                              │                              │
  │                              │ 6. { access_token,           │
  │                              │      refresh_token }         │
  │                              │ ◀────────────────────────────│
  │                              │                              │
  │                              │ 7. KMS-encrypt refresh_token │
  │                              │    Store SPOTIFY_LINK item   │
  │                              │                              │
  │ 200 { linked: true }         │                              │
  │ ◀────────────────────────────│                              │
```

The Spotify **refresh token never touches the iOS app**. The iOS app gets a short-lived Spotify access token when it needs to make a Web API call (via a backend endpoint like `GET /spotify/audio-features/:track_id`), or the backend makes the call on its behalf.

This is the moment where you actually have something worth protecting on the backend. Everything before this point is conventional auth; this is the security justification for the whole backend.

---

## 5. Secrets and IAM

| Secret | Storage | Rotation |
|---|---|---|
| App JWT signing key | KMS customer-managed asymmetric key (`SIGN_VERIFY`, ECC_NIST_P256) | KMS handles automatically; no key material ever leaves KMS |
| Apple JWKS | Public, fetched and cached | Apple rotates; cache with ~24h TTL |
| Spotify `client_secret` | AWS Secrets Manager | Manual rotation when needed; Lambda fetches at cold start, caches in memory |
| DynamoDB encryption KMS key | KMS customer-managed symmetric key | Automatic annual rotation enabled |

**IAM principle:** Each Lambda has its own execution role with the minimum permissions for its function. The auth-handler Lambda can write USER and REFRESH items. The waypoints handler can read/write WAYPOINT items under the authenticated user's `pk` only — enforce this in handler code, not just IAM (IAM can't express row-level access in DynamoDB).

---

## 6. Open questions for review

These are the spots where I made a default call but the right answer depends on your intent:

1. **Apple as identity provider — confirm.** If Android is on the roadmap at any point, "Sign in with Google" should be added alongside Apple from day one. Designing for both is cheap now, expensive later.
2. **Refresh token rotation policy.** Default: rotate on every use, 90-day absolute lifetime. Alternative: rotate weekly, indefinite lifetime. Tradeoff is between security (rotation limits exposure window) and resilience (excessive rotation can lock out users on flaky networks).
3. **Watch app strategy.** The watchOS app currently is a stub. If the watch app is meant to work *independently* of the paired iPhone (e.g., on cellular Apple Watch), the backend needs to broker Spotify Web API calls so the watch never talks to the Spotify SDK directly. That changes the priority of Flow D significantly.
4. **Conflict UX.** When the `version` check fails on a waypoint update, what does the iOS app do? Default in this doc: silently refetch and reapply the local edit on top. Alternative: surface a conflict to the user. The silent strategy is fine for color/position edits; less fine if we ever add user-authored *notes* to waypoints.
5. **Anonymous mode.** Should pre-sign-in users be able to use the app (and have local-only waypoints) with the option to "claim" them by signing in later? Default in this doc: no — sign-in is required for waypoint persistence. Worth confirming.

---

## 7. What this doc is NOT

- It is not a deployment plan (no CloudFormation/CDK/SAM yet).
- It is not an API spec (no endpoint catalog, request/response schemas).
- It is not a migration plan from the current `UserDefaults`-only state.

Each of those is a follow-up doc once the decisions above are confirmed.
