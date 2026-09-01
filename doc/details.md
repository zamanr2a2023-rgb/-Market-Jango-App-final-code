# Flutter — Driver New Order Screen

Use **Phase 6 delivery assignments**, not the legacy order list.

| Do | Do not |
|----|--------|
| `GET /api/driver/deliveries?status=pending` | `GET /api/all-order/driver` (legacy raw dump) |
| `GET /api/driver/deliveries/{assignment_id}` | Treat `invoice_item.id` as accept/reject id |
| Accept / reject with **`assignment_id`** | |

Auth: `token` header (same as other driver APIs) + driver user.

`{id}` on all `/driver/deliveries/{id}/*` routes is **`driver_assignments.id`** (`assignment_id` in the payload).

---

## Screen flow

```text
Claim bin / outlet or vendor assigns
        ↓
assignment status = pending  →  NEW badge
        ↓
GET /driver/deliveries?status=pending   → list cards
  OR claim response already returns the same card payload
GET /driver/deliveries/{assignment_id}  → full New Order card
        ↓
POST .../accept  OR  POST .../reject { "reason": "..." }
        ↓
(after accept) pickup → deliver + live location
```

### Outlet bin path (before Accept)

| UI action | Method | Path | Response |
|-----------|--------|------|----------|
| Browse bin | `GET` | `/api/driver/outlet-bin/{outletId}/orders` | Outlet item preview (`distance_km`, vendor phone, pickup/dropoff…) |
| Claim order | `POST` | `/api/driver/outlet-bin/orders/{itemId}/claim` | **Same New Order DTO** as deliveries (`assignment_id`, `is_new`, Accept/Decline flags) |

After claim, use `data.assignment_id` for accept/reject — do not use the bin `itemId`.

| UI action | Method | Path | Body |
|-----------|--------|------|------|
| New orders list | `GET` | `/api/driver/deliveries?status=pending` | — |
| Order detail | `GET` | `/api/driver/deliveries/{assignment_id}` | — |
| Accept | `POST` | `/api/driver/deliveries/{assignment_id}/accept` | — |
| Decline | `POST` | `/api/driver/deliveries/{assignment_id}/reject` | `{ "reason": "Too far" }` (required) |

---

## Field → UI widget mapping

| Mockup widget | JSON path | Notes |
|---------------|-----------|--------|
| Order ID | `order_number` | Prefer invoice `order_number`; fallback `#` + line id |
| **NEW** badge | `is_new` / `badge` | `true` / `"NEW"` only while `status === "pending"` |
| Card accent color | `order_color_key` / `suggested_color` | Prefer these; `source_color_key` mirrors `order_color_key` |
| From (Pickup) name | `pickup.name` | Vendor business name |
| From address | `pickup.address` | + `pickup.latitude` / `longitude` for map pin |
| To (Drop-off) name | `dropoff.name` | Buyer / receiver name |
| To address | `dropoff.address` | + lat/lng |
| Distance | `metrics.distance_km` | Number (km); format in UI |
| Est. Time | `metrics.estimated_time_minutes` | Computed from distance ÷ avg speed (config) |
| Payment | `metrics.payment_amount` | Driver-facing delivery charge; currency in `metrics.payment_currency` |
| Product / package title | `package.title` | First product, or `Name + N more` when multi-line |
| Item count badge | `package.item_count` | Sum of quantities across trip lines |
| Line count | `package.line_count` | Number of products / invoice lines on the trip |
| Product rows | `package.products[]` | `{ id, name, qty, image, invoice_item_id, assignment_id }` — all lines on the trip |
| Vendor block | `vendor.business_name`, `vendor.contact_name`, `vendor.phone` | Phone from vendor’s user |
| Buyer block | `buyer.name`, `buyer.phone` | |
| Accept enabled | `actions.can_accept` | Only when pending |
| Decline enabled | `actions.can_reject` | Only when pending |
| Accept countdown | `accept_timeout_seconds` | Default `30` — **UI only**; server still accepts while pending |

Detail (`GET .../{id}`) also includes `latest_location` (`latitude`, `longitude`, `heading`, `speed`, `recorded_at`) or `null`.

---

## `order_color_key` → strip / accent colors (buyer brief)

| `order_color_key` | Hex (`suggested_color`) | When |
|-------------------|-------------------------|------|
| `single_vendor` | `#2196F3` (blue) | Marketplace assignment; invoice has **1** vendor |
| `multi_vendor` | `#4CAF50` (green) | Marketplace assignment; invoice has **2+** vendors |
| `outlet` | `#FF9800` (orange) | `assignment_source` is `outlet_direct` or `outlet_bin_claim` |
| `transport` | `#F44336` (red) | Transport shipment job (`job_type: transport`) |

Priority if more than one applies: **outlet > transport > multi/single vendor**.

`source_color_key` is kept as an **alias** of `order_color_key` (same values). Do not map old keys `vendor` / `outlet_bin` / `outlet_assigned` anymore.

### Transport on the same list

`GET /api/driver/deliveries` returns **marketplace** cards and **transport** shipments together.

| Field | Marketplace | Transport |
|-------|-------------|-----------|
| `job_type` | `marketplace` | `transport` |
| `assignment_id` | set | `null` |
| `shipment_id` | `null` | set |
| Detail | `GET .../deliveries/{assignment_id}` | `GET .../deliveries/{shipment_id}?job_type=transport` |

Shipment `booked` maps to list `status: pending` for the Pending tab.

---

## Legacy `assignment_source` (logic only, not accent color)

| `assignment_source` | Meaning |
|---------------------|---------|
| `vendor_direct` | Vendor-assigned |
| `outlet_direct` | Outlet assigned to driver |
| `outlet_bin_claim` | Driver claimed from outlet bin |
| `transport` | Transport shipment |

---

## Example — pending list item

```json
{
  "status": "success",
  "message": "Your deliveries",
  "data": {
    "current_page": 1,
    "data": [
      {
        "assignment_id": 12,
        "status": "pending",
        "is_new": true,
        "badge": "NEW",
        "order_number": "20260814-ABC123",
        "invoice_item_id": 239,
        "job_type": "marketplace",
        "assignment_source": "outlet_bin_claim",
        "order_color_key": "outlet",
        "source_color_key": "outlet",
        "suggested_color": "#FF9800",
        "accept_timeout_seconds": 30,
        "pickup": {
          "label": "From (Pickup)",
          "name": "FreshMart Grocery",
          "address": "123 Market St",
          "latitude": -1.28,
          "longitude": 36.82
        },
        "dropoff": {
          "label": "To (Drop-off)",
          "name": "Juan Dela Cruz",
          "address": "88 Sampaguita St",
          "latitude": -1.30,
          "longitude": 36.85
        },
        "metrics": {
          "distance_km": 5.6,
          "estimated_time_minutes": 9,
          "payment_amount": 120.0,
          "total_pay": 20.0,
          "payment_currency": "USD",
          "payment_method": "PM"
        },
        "package": {
          "title": "Grocery Items",
          "subtitle": null,
          "item_count": 3,
          "quantity": 3,
          "products": [
            { "id": 1, "name": "Grocery Items", "qty": 3, "image": "img.jpg" }
          ]
        },
        "vendor": {
          "id": 1,
          "business_name": "FreshMart Grocery",
          "contact_name": "Maria Santos",
          "phone": "09171234567"
        },
        "buyer": {
          "name": "Juan Dela Cruz",
          "phone": "09987654321",
          "email": "buyer@example.com"
        },
        "actions": {
          "can_accept": true,
          "can_reject": true
        }
      }
    ],
    "per_page": 15,
    "total": 1
  }
}
```

---

## Notes / limits

- **One vendor order trip = one assignment card.** Assigning any line via `POST /vendor/orders/{item_id}/assign-driver` also assigns every other unassigned line on the same invoice for that vendor. The driver list collapses those lines into one card; Accept / Decline / Pickup / Deliver advances the whole trip.
- **Payment** is the stored line `delivery_charge` (single amount). Multi-driver split by distance/weight/volume is **not** returned yet.
- **ETA** is estimated (`config/driver.php` → `avg_speed_kmh`, default 40). Not live traffic.
- **Accept timer** is for UX; hard auto-reject after 30s is not enforced on the server.
- After accept, continue with existing Phase 6 flow: `pickup` → `deliver` / `location` (see [OUTLET_API.md](OUTLET_API.md)).
