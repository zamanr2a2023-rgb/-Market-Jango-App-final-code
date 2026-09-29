# Flutter — Driver Delivery Setting (multi-route pick)

Screen: **Delivery setting** (lang key `delivery_setting`).

Driver can **opt in to many** delivery-charge routes (not one only). Same APIs as vendor.

**Subscription cap:** `GET` returns `data.max_routes` (default **4**) and `data.selected_route_count`. `POST` Add returns **422** when limit reached.

Postman: [`docs/postman/DRIVER_DELIVERY_SETTING_ROUTES.json`](postman/DRIVER_DELIVERY_SETTING_ROUTES.json)  
Also: [`FLUTTER_LAST_EDITES_DRIVER_ORDERS_ROUTES.md`](FLUTTER_LAST_EDITES_DRIVER_ORDERS_ROUTES.md)

---

## Auth headers (every call)

| Header | Value |
|--------|--------|
| `token` | JWT from login |
| `id` | logged-in user id |
| `user_type` | `driver` |

Middleware: `tokenVerify` + `userTypeVerify:vendor,driver`.

---

## Screen flow

```text
Open Delivery setting
        ↓
GET /api/vendor/route-points?search=...&page=1
        ↓
Table from data.items[]
  Action: is_selected == false → "Add"
          is_selected == true  → "Remove"
  Never show "—" for driver (that was the bug)
        ↓
Tap Add  → POST /api/vendor/route-points
           body: { "delivery_charge_route_id": <id> }
        ↓
Tap Remove → DELETE /api/vendor/route-points/{id}
        ↓
Refresh list (or flip local is_selected)
Driver may Add many different routes — capped by subscription `max_routes` (default **4**)
```

---

## APIs

| UI action | Method | Path | Body / query |
|-----------|--------|------|----------------|
| List / search / paginate | `GET` | `/api/vendor/route-points` | `?search=` (zone/from/to), `?page=` |
| Add route | `POST` | `/api/vendor/route-points` | `{ "delivery_charge_route_id": 3 }` |
| Remove route | `DELETE` | `/api/vendor/route-points/{delivery_charge_route_id}` | — |

Path id on DELETE = `items[].id` (delivery charge route id), **not** a pivot row id.

**Subscription limit:** list returns `data.max_routes` + `data.selected_route_count` for drivers. Add returns **422** when `selected_route_count >= max_routes` (default max = **4** if plan unset). See [`FLUTTER_LAST_EDITES_DRIVER_ORDERS_ROUTES.md`](FLUTTER_LAST_EDITES_DRIVER_ORDERS_ROUTES.md).

---

## List response → UI

Envelope: `{ "status", "message", "data": { "items", "pagination", "max_routes?", "selected_route_count?" } }`

| Column / widget | JSON path | Notes |
|-----------------|-----------|--------|
| Zone name | `items[].zone_name` | e.g. `LA` |
| Flat | `items[].flat_base_charge` | or `flat_base_price` / `price` |
| Distance range | `items[].distance_base_range` | e.g. `0<>0`; null → `—` |
| Distance km | `items[].distance_km` | nullable display value |
| Weight | `items[].weight_base_range` | e.g. `10<>100` |
| Cube | `items[].cubic_base_range` | e.g. `100<>2000` |
| Action | `items[].is_selected` | `false` → Add, `true` → Remove |
| Cap | `data.max_routes` | subscription; default 4 |
| Selected count | `data.selected_route_count` | disable Add at limit |
| Search | query `search` | zone / from_point / to_point |
| Pagination | `data.pagination` | `total`, `per_page`, `current_page`, `last_page` |

Optional extras (detail if needed): `from_point`, `to_point`, `weight_ranges[]`, `distance_ranges[]`, `cube_ranges[]`, `currency`, `status`.

### Example item

```json
{
  "id": 12,
  "zone_name": "LA",
  "from_point": "Kampala",
  "to_point": "Entebbe",
  "flat_base_charge": 500.0,
  "distance_base_range": null,
  "weight_base_range": "15<>100",
  "cubic_base_range": "100<>100",
  "is_selected": false
}
```

---

## Action column rules (required fix)

| Condition | Button | Call |
|-----------|--------|------|
| `is_selected == false` | **Add** | `POST` with that row’s `id` |
| `is_selected == true` | **Remove** | `DELETE .../{id}` |
| Driver role | same as vendor | **Do not** hide buttons / show `—` |

After success toast:

- Add → lang `route_added` (“Route added”)
- Remove → optional “Route removed”

Hint under search (hardcoded or local): *Use Add / Remove in Action column to manage routes.*

---

## Multi-route behavior

- Backend stores rows in `driver_delivery_charge_routes` with unique `(driver_id, delivery_charge_route_id)`.
- Calling Add on route A then Add on route B keeps **both**, until `max_routes` is reached.
- Re-Add on an already selected route is idempotent (`firstOrCreate`) — still success (does not consume an extra slot).
- Only Remove clears that one route; others stay.
- New Add when at limit → **422** with `{ max_routes, current_routes }`.

---

## Flutter checklist

1. Remove any `if (userType == driver) Action = "—"` / read-only gate.
2. Parse `data.items`, not a wrong key like `data.routes`.
3. Wire Add → POST, Remove → DELETE with driver headers.
4. Allow many selected rows up to `data.max_routes` (default 4).
5. Disable Add (or toast) when `selected_route_count >= max_routes`; handle 422.
6. After Add/Remove, re-fetch current page (or update that row’s `is_selected`).
7. Search: debounce `GET ...?search=<text>`.
8. Handle 401/403/404 with retry / toast (`failed_to_load`, `retry`).

---

## Errors to expect

| HTTP | When |
|------|------|
| 404 | Driver profile missing, or route not Active / not found |
| 403 | `user_type` not `driver` or `vendor` |
| 422 | Missing / invalid `delivery_charge_route_id` on POST |
| 422 | Driver already at subscription `max_routes` |
| 401 | Bad / missing `token` |

---

## Do / Do not

| Do | Do not |
|----|--------|
| Show Add/Remove for **driver** | Show only `—` for driver |
| Let driver select **many** routes up to `max_routes` | Cap UI at 1 selected route |
| Block Add at subscription limit | Ignore 422 and keep tapping Add |
| Use `items[].id` as `delivery_charge_route_id` | Invent a separate “driver route id” |
| Send `user_type: driver` | Call these endpoints as buyer/admin |
