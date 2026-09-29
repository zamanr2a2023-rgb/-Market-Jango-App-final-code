# Flutter — LAST EDITES: Transport pickup / drop contacts

Shipment create requires **pickup** and **drop-off** contact **name + phone**. Driver delivery payload exposes those contacts.

Postman: [`docs/postman/LAST_EDITES_transport_contacts.json`](postman/LAST_EDITES_transport_contacts.json)

---

## Auth headers

| Header | Value |
|--------|--------|
| `token` | JWT from login |
| `id` | logged-in user id |
| `user_type` | `transport` (create) · `driver` (view job) |

---

## Screen flow

```text
Transport → Find transporter → Create shipment
        ↓
Required contacts:
  pickup_contact_name + pickup_contact_phone
  dropoff_contact_name + dropoff_contact_phone
        ↓
Phone regex: +?[0-9\s-]{7,20}
        ↓
POST /api/shipments
        ↓
Driver opens delivery card
  pickup.name / pickup.phone
  dropoff.name / dropoff.phone
```

---

## APIs

| UI action | Method | Path | Body |
|-----------|--------|------|------|
| Create shipment | `POST` | `/api/shipments` | see body below |
| Driver list | `GET` | `/api/driver/deliveries` | includes shipment jobs |
| Driver detail | `GET` | `/api/driver/deliveries/{id}` | |

---

## Create body (required contacts)

```json
{
  "driver_id": 5,
  "origin_address": "Kampala warehouse",
  "destination_address": "Entebbe airport",
  "pickup_contact_name": "Alice Pickup",
  "pickup_contact_phone": "+256700000001",
  "dropoff_contact_name": "Bob Drop",
  "dropoff_contact_phone": "0700 000 002",
  "packages": [
    { "weight_kg": 5, "quantity": 1 }
  ]
}
```

### Phone validation

| Rule | Pattern |
|------|---------|
| Regex | `^\+?[0-9\s\-]{7,20}$` |
| Examples OK | `+256700000001`, `0700 000 002`, `0700-000-002` |
| Fail | letters, too short, symbols other than `+` space `-` |

---

## Driver payload → UI

| Widget | JSON path |
|--------|-----------|
| Pickup name | `pickup.name` (shipment contact, else fallback) |
| Pickup phone | `pickup.phone` |
| Drop name | `dropoff.name` |
| Drop phone | `dropoff.phone` |

Call driver with headers `user_type: driver`.

---

## Flutter checklist

1. Both name+phone required on create form (4 fields).
2. Client-side phone check matching server regex before submit.
3. Show contacts on driver job card (not only addresses).

---

## Errors to expect

| HTTP | When |
|------|------|
| 422 | Missing contact fields or phone regex fail |
| 404 | Driver not found |
| 403 | Wrong `user_type` |

---

## Do / Do not

| Do | Do not |
|----|--------|
| Require all four contact fields | Rely on transport user name only |
| Validate phone with `+?[0-9\s-]{7,20}` | Allow letters / empty phone |
| Show name+phone on driver card | Hide phone after booking |
