# UWA connection handover

Status: provisions only, awaiting UWA requirements at the user's direction.
The contract and Notebook describe the intended architecture, not endpoint
credentials, hardware protocols or service authorization.

| Service | Required information | Current implementation |
|---|---|---|
| Dispatch | HTTPS API, authorization, routing, payload, receipts, retry/idempotency policy, sandbox | Disabled generic JSON POST adapter; admin explicitly submits |
| SMS | Provider, sender ID approval, contact consent, delivery receipts, tariffs | Disabled provision |
| Radio | Make/model, gateway, serial/BLE/IP protocol, permitted frequencies, pairing/encryption | Disabled provision; no RF transmission |
| Satellite | Terminal, subscription, SDK/API, payload limits, receipt format | Disabled provision; no satellite transmission |
| EarthRanger | Instance URL, OAuth access, event types, subject groups, attachments, test permissions | Disabled provision; no EarthRanger traffic |

Dispatch sends `id`, `type`, `description`, `latitude`, `longitude`, `reportedAt`
and `Idempotency-Key` equal to incident ID. The gateway must enforce that key.
HTTP success is stored as `Submitted`, not proof of responder acceptance.
External retry workers and receipt ingestion await the approved provider contract.

After access arrives: implement the adapter, validate in a sandbox, agree on event
mapping and data ownership, add durable retries and verified delivery receipts,
then test disconnect/reconnect, duplicate delivery and field range with responders.
For EarthRanger, agree on the authoritative system before synchronizing records.

## Emergency directory sources

- Police 999/112: https://upf.go.ug/faq/
- Tourist Police 0800300117: Uganda Police Annual Crime Report 2024,
  https://upf.go.ug/wp-content/uploads/2025/02/ACR2024-Web.pdf
- Medical/ambulance 912 and alternate health line 0800100066:
  https://alerts.health.go.ug/add-alert

Reviewed 28 September 2026. Listed numbers do not guarantee service availability
in every park/network. UWA should validate contacts, guides and safety content.
