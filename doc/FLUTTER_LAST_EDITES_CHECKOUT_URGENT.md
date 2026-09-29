# Flutter — LAST EDITES: Checkout Normal vs Urgent

Buyer checkout can choose **Normal** or **Urgent**. Urgent adds Admin route `urgent_flat_fee` into delivery total. Toggle is **checkout only**.

Postman: [`docs/postman/LAST_EDITES_checkout_urgent.json`](postman/LAST_EDITES_checkout_urgent.json)

---

## Auth headers (every call)

| Header | Value |
|--------|--------|
| `token` | JWT from login |
| `id` | logged-in user id |
| `user_type` | `buyer` |

---

## Screen flow

```text
Checkout screen
        ↓
UI toggle: Normal (is_urgent=0) | Urgent (is_urgent=1)
        ↓
GET /api/cart/delivery-charges?is_urgent=0|1
   (or same key in JSON body)
        ↓
Show totals:
  cart_total_delivery_charge
  cart_urgent_fee
  routes[].urgent_fee, routes[].distance_km
        ↓
If 422 missing weight/cube → block Pay, show product message
        ↓
POST /api/invoice/create
  body includes is_urgent: true|false
        ↓
Vendor / driver / outlet order cards:
  is_urgent true → red strip #FF0000
  order_color_key = urgent
  suggested_color = #FF0000
```

---

## APIs

| UI action | Method | Path | Body / query |
|-----------|--------|------|----------------|
| Preview delivery (normal) | `GET` | `/api/cart/delivery-charges` | `?is_urgent=0` |
| Preview delivery (urgent) | `GET` | `/api/cart/delivery-charges` | `?is_urgent=1` |
| Place order | `POST` | `/api/invoice/create` | `{ "payment_method": "...", "is_urgent": true }` |

`is_urgent` also accepted from request body on the GET if the client prefers POST-style input (query preferred).

---

## Delivery-charges response → UI

Envelope: `{ "status", "message", "data": { ... } }`

| Widget | JSON path | Notes |
|--------|-----------|--------|
| Urgent on/off echo | `data.is_urgent` | bool |
| Extra urgent total | `data.cart_urgent_fee` | sum of route urgent fees |
| Delivery total | `data.cart_total_delivery_charge` | includes urgent when on |
| Grand total | `data.cart_total_with_delivery_and_fees` | |
| Per route urgent | `data.routes[].urgent_fee` | 0 when normal |
| Per route distance | `data.routes[].distance_km` | nullable km |

### Example (urgent)

```json
{
  "is_urgent": true,
  "cart_urgent_fee": 1500.0,
  "cart_total_delivery_charge": 8500.0,
  "routes": [
    {
      "from_point": "Kampala",
      "to_point": "Entebbe",
      "urgent_fee": 1500.0,
      "distance_km": 42.5,
      "cost": 8500.0
    }
  ]
}
```

---

## Invoice create

`POST /api/invoice/create`

```json
{
  "payment_method": "OPU",
  "is_urgent": true
}
```

Same cart totals engine as delivery-charges. Invoice stores `is_urgent` + `urgent_fee`.

---

## Missing weight / cube (block checkout)

If any cart product lacks weight or cube (from L×W×H), both preview and create return **422**:

```json
{
  "status": "failed",
  "message": "Product missing required weight/cube for delivery: Sugar 1kg",
  "data": { "product_id": 12, "missing": ["weight", "cube"] }
}
```

Flutter: disable Pay / show toast until vendor fixes product dimensions.

---

## Vendor / driver / outlet color

When `invoice.is_urgent == true` (or delivery payload `is_urgent`):

| Field | Value |
|-------|--------|
| Strip / accent | `#FF0000` |
| `order_color_key` | `urgent` |
| `suggested_color` | `#FF0000` |

Driver list/detail already returns these on urgent jobs. Vendor/outlet: prefer `is_urgent` on the invoice relation; if `order_color_key` is not `urgent` yet, still paint red when `is_urgent` is true.

---

## Flutter checklist

1. Toggle only on checkout — not home / product / cart list.
2. Re-fetch delivery-charges when toggle flips.
3. Pass the same `is_urgent` on invoice create.
4. Handle 422 missing weight/cube before payment.
5. Paint urgent orders red on vendor, driver, outlet.

---

## Errors to expect

| HTTP | When |
|------|------|
| 422 | Product missing weight/cube |
| 422 | Buyer missing `ship_zone` / `ship_town` |
| 404 | Empty cart / buyer not found |
| 401 | Bad / missing `token` |

---

## Do / Do not

| Do | Do not |
|----|--------|
| Default toggle to **Normal** | Always send `is_urgent: true` |
| Show urgent fee only when Urgent selected | Hide fee but still charge it |
| Block checkout on missing weight/cube | Charge flat-only when dims missing |
| Use `#FF0000` for urgent cards | Reuse transport red logic for non-urgent |
