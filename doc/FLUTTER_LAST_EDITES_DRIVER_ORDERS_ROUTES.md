# Flutter — LAST EDITES: Driver orders filters + route limit + outlet assign

Driver **Orders** search/filter. Delivery Setting respects subscription **`max_routes`** (default **4**). Urgent orders red. Vendor outlet assign already exists.

Postman: [`docs/postman/LAST_EDITES_driver_orders_routes.json`](postman/LAST_EDITES_driver_orders_routes.json)  
Related: [`FLUTTER_DRIVER_DELIVERY_SETTING_ROUTES.md`](FLUTTER_DRIVER_DELIVERY_SETTING_ROUTES.md)

---

## Auth headers

| Header | Value |
|--------|--------|
| `token` | JWT from login |
| `id` | logged-in user id |
| `user_type` | `driver` (orders / routes) · `vendor` (assign outlet) |

---

## Screen flow — Driver Orders

```text
Driver → Orders
        ↓
Filters:
  order_number, pick_location, drop_location,
  from_date, to_date, status
        ↓
GET /api/driver/deliveries?...
        ↓
Cards:
  is_urgent true → red #FF0000
  order_color_key=urgent, suggested_color=#FF0000
  metrics / routes may include distance_km
```

---

## Screen flow — Delivery Setting (route limit)

```text
GET /api/vendor/route-points
  data.max_routes
  data.selected_route_count
  data.items[].distance_km
  data.items[].is_selected
        ↓
If selected_route_count >= max_routes:
  disable Add (or show blocked)
        ↓
POST Add → 422 when over subscription limit
DELETE Remove → frees a slot
```

Default `max_routes` = **4** when plan has no value.

---

## APIs

| UI action | Method | Path | Query / body |
|-----------|--------|------|----------------|
| Driver orders | `GET` | `/api/driver/deliveries` | filters below |
| List routes | `GET` | `/api/vendor/route-points` | `?search=` `?page=` |
| Add route | `POST` | `/api/vendor/route-points` | `{ "delivery_charge_route_id": n }` |
| Remove route | `DELETE` | `/api/vendor/route-points/{id}` | — |
| Assign outlet | `POST` | `/api/vendor/orders/{item_id}/assign-outlet` | `{ "outlet_id": n }` |

### Driver deliveries filters

| Query | Purpose |
|-------|---------|
| `order_number` | Order number search (also `q`) |
| `pick_location` | Pickup address contains |
| `drop_location` | Drop / ship address contains |
| `from_date` | `YYYY-MM-DD` created ≥ |
| `to_date` | `YYYY-MM-DD` created ≤ |
| `status` | e.g. `pending`, `accepted`, `in_transit`, `delivered` (or `all`) |
| `page`, `per_page` | pagination |

---

## Route list extras (driver)

| Field | Notes |
|-------|--------|
| `data.max_routes` | From active subscription plan (default 4) |
| `data.selected_route_count` | How many routes driver already added |
| `items[].distance_km` | Display / filter |
| `items[].is_selected` | Add vs Remove |
| `items[].urgent_flat_fee` | Admin urgent fee on route |

When Add hits limit:

```json
{
  "status": "failed",
  "message": "Route limit reached for your subscription (4). Remove a route before adding another.",
  "data": { "max_routes": 4, "current_routes": 4 }
}
```

HTTP **422**.

---

## Urgent on order cards

| Field | Value when urgent |
|-------|-------------------|
| `is_urgent` | `true` |
| `order_color_key` | `urgent` |
| `suggested_color` | `#FF0000` |

---

## Vendor — assign outlet (already exists)

```text
POST /api/vendor/orders/{item_id}/assign-outlet
Body: { "outlet_id": 3 }
Headers: user_type=vendor
```

`item_id` = invoice item id. Unassign: `POST .../unassign-outlet`.

---

## Flutter checklist

1. Wire all five order filters + status chip.
2. Show `max_routes` / `selected_route_count` under Delivery Setting.
3. Hide or disable Add at limit; toast on 422.
4. Show `distance_km` on route rows when present.
5. Paint urgent jobs red.
6. Vendor order screen: keep assign-outlet (in addition to assign driver).

---

## Errors to expect

| HTTP | When |
|------|------|
| 422 | Route Add over `max_routes` |
| 404 | Driver / route / order not found |
| 403 | Wrong `user_type` |

---

## Do / Do not

| Do | Do not |
|----|--------|
| Cap Add using `max_routes` | Allow unlimited Add in UI |
| Filter orders by pick/drop/date/number | Client-only filter without API params |
| Use `#FF0000` for `is_urgent` | Ignore urgent on driver list |
| Call existing assign-outlet | Invent a new outlet-assign endpoint |
