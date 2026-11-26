# Gear Tracker API

A JSON API for agents and scripts: read your gear, and log expenses, fuel and
energy use, and readings. It sees and changes only the data of the user who
made the token.

This page is served at `/api/v1` on every Gear Tracker server, and kept in the
repository as `docs/api.md`.

## Quick start

1. Sign in on the website, open **Settings**, and create a token under
   **API tokens**. Copy it: it's shown only once.
2. Send it in the `Authorization` header of every request, over HTTPS:

```sh
curl https://your-server/api/v1/gears \
  -H "Authorization: Bearer gt_your_token"
```

3. To log something, send JSON:

```sh
curl https://your-server/api/v1/gears/12/fuel_entries \
  -H "Authorization: Bearer gt_your_token" \
  -H "Content-Type: application/json" \
  -d '{"amount": 0.014, "hours": 3, "notes": "Bedroom"}'
```

## For agents

- Call `GET /api/v1/me` first to learn the user's currency and units.
- Find the gear with `GET /api/v1/gears`, matching on `name`, then use its `id`.
- Send dates as `YYYY-MM-DD`. Work out "today" or "yesterday" yourself.
- Amounts, odometer and distances are in the user's units, not metric. The
  response names the unit in fields like `amount_unit` and `distance_unit`.
- Unknown fields are rejected, so a misspelled field fails loudly instead of
  being lost. Read `error` and `details` in the response and try again.
- Confirm with the user before deleting anything.

## Tokens

- Create and revoke tokens in **Settings → API tokens**. Give each agent its own
  token, so you can revoke one without affecting the others.
- **Read only** tokens can only use `GET`. **Read and write** tokens can also
  create, change and delete records.
- A token can't change your password, email address, settings or tokens, and
  can't delete gear. Do those on the website.
- Only a fingerprint (SHA-256 digest) of each token is stored, so a lost token
  can't be shown again. Revoke it and make a new one.
- Tokens only work in the `Authorization` header, never in the URL, and a
  signed-in browser session doesn't work for the API.

## Endpoints

All paths start with `/api/v1`. Ids are whole numbers.

| Method | Path | What it does |
| --- | --- | --- |
| GET | `/me` | Your currency, units, and this token's name and access |
| GET | `/gears` | All your gear, with total cost |
| GET | `/gears/:id` | One gear, with its components |
| POST | `/gears` | Add gear |
| PATCH | `/gears/:id` | Change gear |
| GET | `/gears/:gear_id/expenses` | A gear's expenses, newest first |
| GET | `/gears/:gear_id/expenses/:id` | One expense |
| POST | `/gears/:gear_id/expenses` | Add an expense |
| PATCH | `/gears/:gear_id/expenses/:id` | Change an expense |
| DELETE | `/gears/:gear_id/expenses/:id` | Delete an expense |

Fuel and energy entries (`/gears/:gear_id/fuel_entries`) and readings
(`/gears/:gear_id/readings`) work the same way as expenses.

Lists return up to 100 records, newest first. Add `?limit=` for up to 500.

`PATCH` changes only the fields you send. `POST` returns `201 Created` with the
new record, and `DELETE` returns `204 No Content`.

## Fields

Optional fields can be left out. Send `null` to clear one.

### Gear

| Field | Notes |
| --- | --- |
| `name` | Required, except for vehicles with a year, make, model or trim, which are named by those |
| `category` | One of `vehicle`, `bicycle`, `parts`, `tools`, `electronics`, `computers`, `appliances`, `kitchen`, `heating_cooling`, `household`, `outdoor`, `sports`, `clothing`, `music` or `other`; the name, like `Heating & cooling`, works too. Leave out for none. Responses include its `category_name`. Vehicles and their parts get odometer fields on the website. |
| `year`, `make`, `model`, `trim` | For vehicles, like `2010`, `Toyota`, `Prius` and `Two` |
| `power_source` | `manual`, `gasoline`, `diesel`, `propane`, `electric` or `plug_in_hybrid`. Leave out for gear that isn't powered. |
| `parent_id` | Makes this gear a component of another of your top-level gear |
| `purchased_on` | Date |
| `price` | Number |
| `currency` | `USD`, `EUR`, `GBP`, `CAD`, `AUD`, `JPY`, `KRW`, `INR`, `MXN` or `VND`. Defaults to your currency. |
| `purchased_from`, `notes` | Text |

Responses also include `fuel_kinds` (what its fuel entries can be: `fuel`,
`energy` or both), `total_cost` and `cost_per_year`. Totals are lists with one
amount per currency, since amounts in different currencies aren't added up.

### Expenses

| Field | Notes |
| --- | --- |
| `date` | Required |
| `description` | Required |
| `amount` | Required number |
| `currency` | Defaults to your currency |
| `odometer` | Optional, in your distance unit (`distance_unit` in responses) |
| `category` | One of `maintenance`, `repair`, `tires`, `parts`, `insurance`, `registration`, `taxes`, `financing`, `parking`, `cleaning`, `subscriptions` or `other`; the name, like `Parking & tolls`, works too. Leave out for none. Responses include its `category_name`. Log fuel and charging as fuel entries instead. |
| `vendor`, `notes` | Text |

### Fuel and energy entries

Only for gear with a power source that uses fuel or electricity.

| Field | Notes |
| --- | --- |
| `kind` | `fuel` or `energy`. Only needed for plug-in hybrids, and can't be changed later. |
| `amount` | Required. Fuel is in your volume unit (gallons or liters); energy is in kWh. |
| `date` | Defaults to today |
| `total_price`, `currency` | What it cost |
| `hours`, `minutes` | Time used; send either or both, and they're added up |
| `odometer`, `trip` | In your distance unit. `trip` is the distance since the entry before; without it, it's worked out from the odometers, except for plug-in hybrids. |
| `filled_up` | `true` (the default) if the tank is now full, or the battery is at its usual level; `false` for a partial fill-up |
| `missed_previous` | `true` if a fill-up or charge before this one wasn't logged; `false` is the default. There's no efficiency until the next full one, unless `trip` is the distance since the missed one. |
| `efficiency_checked` | `true` if the user says an unusual efficiency is right; `false` is the default. Ask them first. |
| `notes` | Text |

Responses also include the units, `minutes` (total time used), `rate` (watts
for energy, or fuel per hour), `distance` (since the entry before: `trip`, or
worked out) and `efficiency` (like miles per gallon, since the last time it was
full; `null` for a partial fill-up, which counts toward the next full one). `missed_before` is about how many went
unlogged just before this one. `efficiency_flag` is `high` or `low` when the
efficiency is unusual for this gear and the user hasn't checked it.

### Readings

| Field | Notes |
| --- | --- |
| `date` | Required |
| `name` | Required, like `Tire pressure FL` |
| `value` | Required number |
| `unit` | Text, like `psi` |
| `odometer` | Optional, in your distance unit (`distance_unit` in responses) |
| `notes` | Text |

## Errors

Errors are JSON with an `error` message, and for invalid records `details` per
field:

```json
{
  "error": "Description can't be blank",
  "details": { "description": ["can't be blank"] }
}
```

| Status | Meaning |
| --- | --- |
| 400 | The body isn't valid JSON |
| 401 | Missing, wrong or revoked token |
| 403 | The token is read-only |
| 404 | Not found, or not yours |
| 422 | An unknown field, a bad date, or a record that isn't valid |
| 429 | More than 100 requests in a minute from your address |
