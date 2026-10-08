# Flutter — Influencer links: Edit vendor affiliate program

**Scope:** Add **Edit** (bottom-right) on **Influencer links**. Opens the **existing Store affiliate link** setup screen (same as first-time vendor affiliate setup). Not per-influencer edit. No new backend APIs.

**Buyer ref:** Edit opens the form already implemented when the vendor sets affiliate initially.

---

## UI

| Screen | Action |
|--------|--------|
| **Influencer links** | Keep list, approve, copy, delete unchanged. Add **Edit** bottom-right (FAB). |
| **Edit tap** | Navigate to **Store affiliate link** screen (reuse widget). |

---

## APIs

Base: `/api/affiliate/…` — vendor `token` header (same as rest of app).

| Step | Method | URL |
|------|--------|-----|
| Load | GET | `/affiliate/links` |
| Create (no link yet) | POST | `/affiliate/generate` |
| Update | PUT | `/affiliate/link/{id}` |

Influencer list stays: `GET /vendor-dashboard/influencer-referral-links` (unchanged).

---

## Form fields

Match initial setup only:

- `name`, `description`, `destination_url`
- `custom_rate` (0–100)
- `cookie_duration_days`
- `attribution_model`: `first_click` \| `last_click`
- `expires_at`, `status` — only if already on setup screen

`destination_url` optional on create; backend auto-fills `{APP_URL}/shop/{userId}` when omitted.

**Link code / URL:** read-only + copy from response. Do not allow editing `link_code` (not in `PUT`).

Vendor max **one** store link.

---

## Errors

- **403** — affiliate not in subscription plan.
- **422** on `POST /generate` (“already have one link”) → `GET /links` then **PUT** edit mode.

---

## Out of scope

- New backend endpoints
- Edit influencer row
- Screenshot / SS upload (`FLUTTER_STEP_09_AFFILIATE.md`)

---

## Checklist

- [ ] Edit bottom-right on Influencer links
- [ ] Reuse Store affiliate link screen
- [ ] `GET /links` → pre-fill or `POST /generate` if empty
- [ ] Save via `PUT /link/{id}` when link exists

**More API detail:** `POSTMAN_AFFILIATE_API_WHO_AND_DETAILS.md` §3.0 STORE AFFILIATE LINK.
