# Flutter — LAST EDITES: Product walk-in pricing

Product upload requires **marketplace sell price**, **walk-in sell price**, and **buying price**. Marketplace and walk-in share the **same stock**. Manual / walk-in orders bill `walk_in_sell_price`.

Postman: [`docs/postman/LAST_EDITES_product_walkin.json`](postman/LAST_EDITES_product_walkin.json)

---

## Auth headers (every call)

| Header | Value |
|--------|--------|
| `token` | JWT from login |
| `id` | logged-in user id |
| `user_type` | `vendor` |

Also send `email` header if your app already does for product APIs.

---

## Screen flow

```text
Vendor → Add product
        ↓
Required fields:
  weight, length, width, height
  buying_price
  walk_in_sell_price
  sell_price (marketplace) + regular_price
  image + gallery files
        ↓
POST /api/product/create (multipart)
        ↓
One stock number for both marketplace + walk-in
        ↓
Walk-in / POS / manual order
  → unit price = walk_in_sell_price (fallback sell_price)
Marketplace cart
  → unit price = sell_price
```

---

## APIs

| UI action | Method | Path | Body |
|-----------|--------|------|------|
| Create product | `POST` | `/api/product/create` | multipart form (see below) |
| Update product | `POST` | `/api/product/update/{id}` | same fields; walk-in optional on update |
| Manual order | `POST` | `/api/vendor/manual-orders` | uses product `walk_in_sell_price` |

---

## Create — required pricing / dims

| Field | Required | Notes |
|-------|----------|--------|
| `sell_price` | yes | Marketplace price |
| `regular_price` | yes | Strike / list |
| `buying_price` | yes | Cost (owner) |
| `walk_in_sell_price` | yes | Walk-in / POS sell |
| `weight` | yes | `> 0` |
| `length`, `width`, `height` | yes | Used for cube at checkout |
| `stock` | optional | Shared inventory |
| `weight_unit` | optional | `kg` / `gram` (default kg) |
| `dimension_unit` | optional | `cm` / `m` / `mm` / `in` |

### Multipart example fields

```text
name=Sugar 1kg
regular_price=150
sell_price=140
buying_price=100
walk_in_sell_price=130
stock=50
weight=1
length=10
width=10
height=10
image=<file>
files[]=<file>
```

---

## Pricing rules

| Channel | Unit price | Stock |
|---------|------------|--------|
| Marketplace (cart / invoice) | `sell_price` | same `stock` |
| Walk-in / manual order | `walk_in_sell_price` | same `stock` |
| Profit / cost | `buying_price` | one cost for both |

Buyer confirmed (`2000.pdf`): separate walk-in sell price; both channels feed **same stock** and same buying price, different selling prices.

---

## Flutter checklist

1. Form validation: block save if any of weight / L / W / H / buying / walk-in / sell missing.
2. Label walk-in field clearly (not “cost”).
3. Manual order UI shows walk-in price, not marketplace sell.
4. Do not maintain a second stock field.

---

## Errors to expect

| HTTP | When |
|------|------|
| 422 | Missing required price / weight / dims |
| 404 | Vendor not found |
| 403 | Category not allowed for vendor |

---

## Do / Do not

| Do | Do not |
|----|--------|
| Require `walk_in_sell_price` on create | Treat walk-in as buying price only |
| Use one `stock` for both channels | Duplicate stock for walk-in |
| Manual orders → `walk_in_sell_price` | Charge marketplace `sell_price` for walk-in |
