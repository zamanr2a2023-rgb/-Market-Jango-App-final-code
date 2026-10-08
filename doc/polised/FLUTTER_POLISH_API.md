# Flutter — POLISH backend API contract

Backend scope for POLISH (buyer transport module, quantity approval, driver filters, affiliate edit). **No Flutter UI in this repo.**

Auth headers: `token`, `id`, `user_type` (unchanged JWT; buyers keep `user_type: buyer` when using Transport).

---

## Buyer + Transport (same login)

| Action | Method | Path |
|--------|--------|------|
| Enable transport profile | `POST` | `/api/buyer/transport/enable` |
| Shipments / transport wallet | existing `/api/shipments/*`, `/api/transport/wallet/*` | Allowed when `user.canUseTransportModule()` (buyer with `transports` row or `user_type=transport`) |

Login / `GET /api/user/detail` include `modules.transport: true|false`.

---

## Quantity reduction (buyer approval)

| Action | Method | Path |
|--------|--------|------|
| Vendor requests lower qty | `PATCH` | `/api/vendor/orders/{invoice_item_id}/quantity` |
| List pending (buyer) | `GET` | `/api/buyer/orders/quantity-changes/pending` |
| Buyer accept | `POST` | `/api/buyer/orders/{item_id}/quantity-changes/{request_id}/accept` |

**Decrease:** response includes `change_request` (`status: pending`); line quantity **unchanged** until accept; `auto_refund.skip_reason: pending_buyer_approval`.

**Increase:** still immediate (same PATCH).

**Buyer push:** `type: order_quantity_change_pending` then after accept wallet refund via existing `auto_line_refund`.

**Reject flow:** not specified — not implemented.

---

## Driver order assignment filters

`GET /api/driver/deliveries`

| Query | Aliases |
|-------|---------|
| `pickup_location` | `pick_location` |
| `drop_location` | — |
| `transport_type` | `car`, `motorcycle`, `air`, `water` (transport jobs) |
| `page`, `per_page`, `status`, `from_date`, `to_date` | unchanged |

`GET /api/driver/outlet-bin/{outletId}/orders` — same `pickup_location`, `drop_location`, `transport_type` (server-side).

---

## Vendor affiliate edit

See [FLUTTER_VENDOR_AFFILIATE_EDIT.md](FLUTTER_VENDOR_AFFILIATE_EDIT.md).

---

## Admin-only (Flutter N/A)

Outlet assignment from admin panel uses `/api/admin/orders/{item_id}/assign-outlet`.
