# Flutter — Wallet refund on Cancel line / Accept quantity reduction

## Cancel line (unchanged path)

When vendor (or admin) **cancels a line**, the backend still:

1. Cancels the line (stock, totals, driver assignment)
2. **Credits the buyer wallet immediately** when payment was collected
3. Push `type: auto_line_refund` with `change_type: cancel`

`POST /api/vendor/orders/{invoice_item_id}/cancel` — same as before.

---

## Quantity reduction (POLISH — buyer approval required)

1. Vendor `PATCH /api/vendor/orders/{invoice_item_id}/quantity` with **lower** `quantity`.
2. Backend creates `change_request` (`status: pending`). **Line qty and wallet unchanged.**
3. Buyer notified: `type: order_quantity_change_pending`.
4. Buyer `POST /api/buyer/orders/{item_id}/quantity-changes/{request_id}/accept`.
5. Then line qty, totals, stock update and **wallet credit** (if paid) with `auto_line_refund` / `change_type: quantity_reduce`.

### Vendor PATCH decrease response

```json
{
  "change_request": { "id": 1, "status": "pending", "proposed_quantity": 1, ... },
  "auto_refund": {
    "credited": 0,
    "skipped": true,
    "skip_reason": "pending_buyer_approval",
    "refund_id": null
  }
}
```

### Quantity **increase**

Still immediate on PATCH (no approval).

---

## Buyer endpoints

| Method | Path |
|--------|------|
| GET | `/api/buyer/orders/quantity-changes/pending` |
| POST | `/api/buyer/orders/{item_id}/quantity-changes/{request_id}/accept` |

See also [FLUTTER_POLISH_API.md](FLUTTER_POLISH_API.md).
