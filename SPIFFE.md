# SPIFFE in this lab

This lab wires Vault’s **SPIFFE secrets engine** (issuer) to Vault’s **SPIFFE auth method** (relying party) on the **same cluster**. A workload that already has a Vault token mints a JWT-SVID; that JWT is then presented back to Vault as a Bearer token to log in as a SPIFFE identity.

Official references:

- [SPIFFE secrets engine](https://developer.hashicorp.com/vault/docs/secrets/spiffe)
- [Enable and use the SPIFFE secrets engine](https://developer.hashicorp.com/vault/docs/secrets/spiffe/spiffe)
- [Mint, verify, and use a SVID](https://developer.hashicorp.com/vault/docs/secrets/spiffe/mint-svid)
- [SPIFFE auth method](https://developer.hashicorp.com/vault/docs/auth/spiffe/spiffe)

Both plugins require **Vault Enterprise**. This repo pins `vault_version` to `1.19-ent` and the Vault Terraform provider to `~> 5.12.0` so the SPIFFE resources exist.

## Goal

Show a closed loop:

1. Vault issues a JWT-SVID for App A (`spiffe://example.org/ns/blue/sa/app-a`).
2. The SPIFFE auth method trusts the **same** signing keys (the secrets-engine trust bundle).
3. Login succeeds only when the JWT `sub` matches the auth role’s workload pattern **and** the JWT `aud` is on the auth mount’s audience allow-list.
4. The resulting Vault token can read `blue/kv/data/app/config` (via the `blue` policy) and mint another App A SVID (via `spiffe-app-a`).

This is the same pattern you would use across **two** Vault clusters (cluster A mints, cluster B authenticates). Here both mounts live in root so you can exercise it with one `terraform apply` plus a trust-bundle handoff.

## Architecture

```
  Existing Vault identity
  (root token, AppRole, Kubernetes, LDAP, …)
              |
              |  write spiffe/role/app-a/mintjwt
              |  audience = vault
              v
  ┌─────────────────────────────┐
  │  Secrets engine: spiffe/    │  trust domain: example.org
  │  Roles: app-a, app-b        │  signs JWT-SVIDs (RS256)
  │  GET …/trust_bundle/web     │  publishes JWKS
  └──────────────┬──────────────┘
                 |
                 |  static JWKS copied into auth config
                 v
  ┌─────────────────────────────┐
  │  Auth method: auth-spiffe/  │  profile: static
  │  Role: app-a                │  pattern: /ns/blue/sa/app-a
  │  Authorization: Bearer JWT  │  audience must match mint
  └──────────────┬──────────────┘
                 |
                 |  POST auth/auth-spiffe/login
                 v
           Vault token
           policies: blue, spiffe-app-a
```

| Direction | Plugin | Mount | What it does |
| --- | --- | --- | --- |
| Issue | SPIFFE secrets engine | `spiffe/` | Mints JWT-SVIDs for callers who already have a Vault token |
| Consume | SPIFFE auth method | `auth-spiffe/` | Validates a JWT-SVID and issues a new Vault token |

The secrets engine is its own signer. It does **not** use the PKI secrets engine or SPIRE. The auth method does not mint anything; it only verifies SVIDs against a trust bundle.

## What Terraform creates

### Secrets engine (`secret.tf`)

| Resource | Value |
| --- | --- |
| Mount | `spiffe/` in the root namespace |
| Trust domain | `example.org` |
| Signing | RS256, OIDC compatibility **off** |
| Role `app-a` | `sub` = `spiffe://example.org/ns/blue/sa/app-a`, TTL 1h, `jti` claim on |
| Role `app-b` | `sub` = `spiffe://example.org/ns/red/sa/app-b`, TTL 1h, `jti` claim on |
| Policy `spiffe-app-a` | read `spiffe/trust_bundle/web`; create/update `spiffe/role/app-a/mintjwt` |
| Policy `spiffe-app-b` | same for the `app-b` mint path |

`use_jti_claim = true` puts a unique `jti` on each minted JWT so a relying party can reject replays.

### Auth method (`auth.tf`)

| Resource | Value |
| --- | --- |
| Mount | `auth-spiffe/` (not the default `spiffe` path, so it does not collide with the secrets engine) |
| Tune | `passthrough_request_headers = ["Authorization"]` — required so Vault forwards the Bearer JWT into the plugin |
| Profile | `static` |
| Trust domain | `example.org` (must match the issuer) |
| Bundle | `jsonencode(var.static_bundle)` — JWKS copied from the secrets engine |
| Role `app-a` | `workload_id_patterns = ["/ns/blue/sa/app-a"]` |
| Token | policies `blue` + `spiffe-app-a`; TTL 1h; max TTL 2h; explicit max TTL 3h; **1 use**; period 60s; type `service` |
| Alias metadata | `spiffe = true` |

There is **no** SPIFFE auth role for App B yet. You can mint an App B JWT; you cannot log it in until you add a matching auth role.

`workload_id_patterns` is the **path** of the SPIFFE ID after the trust domain. Vault matches it against `sub` on the JWT (`spiffe://example.org` + pattern).

### Why a static bundle (not `https_web_bundle`)

This cluster runs Vault with TLS disabled (`tls_disable` in the Helm values, UI on `http://localhost:30001`). Remote profiles (`https_web_bundle`, `https_spiffe_bundle`) fetch JWKS over **HTTPS** and fail against this listener.

So the lab snapshots the issuer’s JWKS and pastes it into the auth config:

```
GET /v1/spiffe/trust_bundle/web  →  var.static_bundle  →  auth/auth-spiffe/config
```

`auth.tf` still has the HTTPS fetch approach commented out for when Vault is served with TLS.

## Bootstrap (two applies)

The secrets engine generates signing keys **when it is configured**. The auth method cannot verify minted JWTs until it has those public keys. That is a chicken-and-egg: you cannot know the JWKS before the first apply.

1. Apply with a placeholder or previously captured bundle so the engine and auth mounts exist. If `static_bundle` is empty or stale, mint/login will fail until you refresh it.

2. Read the **live** trust bundle (do not reuse a file from an older cluster; keys rotate, default key lifetime is 24h):

```
export VAULT_ADDR="http://localhost:30001"
export VAULT_TOKEN="root"
export VAULT_NAMESPACE="root"

http $VAULT_ADDR/v1/spiffe/trust_bundle/web "X-Vault-Token: $VAULT_TOKEN"
```

CLI equivalent:

```
vault read -format=json spiffe/trust_bundle/web | jq '.data'
```

The payload looks like:

```json
{
  "keys": [
    {
      "use": "jwt-svid",
      "kty": "RSA",
      "kid": "...",
      "n": "...",
      "e": "AQAB"
    }
  ],
  "spiffe_refresh_hint": 3600
}
```

3. Put that object in Terraform. Either copy it to `trust_bundle.json` and pass it in, or set `static_bundle` in your tfvars as the decoded JWKS object. `variables.tf` exposes `static_bundle` for this.

Example `-var`:

```
terraform apply -var='static_bundle={"keys":[...],"spiffe_refresh_hint":3600}'
```

Or in a tfvars file (HCL):

```hcl
static_bundle = {
  keys = [
    # paste keys from trust_bundle/web
  ]
  spiffe_refresh_hint = 3600
}
```

4. Apply again so `vault_spiffe_auth_backend_config` updates `bundle`.

5. Confirm the auth mount allow-lists the audience you will mint with. **An empty audience list rejects every JWT-SVID.** If login fails with an audience error, set it on the mount (Terraform `audience` on `vault_spiffe_auth_backend_config`, or):

```
vault write auth/auth-spiffe/config \
  trust_domain=example.org \
  profile=static \
  bundle=@trust_bundle.json \
  audience=vault
```

Audience is **mount-wide**, not per role. Mint and login must use the same value.

Whenever the secrets engine rotates keys, refresh `static_bundle` and re-apply. Until you do, new JWTs signed with a new `kid` will not verify.

## Lab walkthrough

Prerequisites: lab applied, Vault UI/API reachable, `jq` installed. Use the UI NodePort or the in-cluster service, consistently:

```
export VAULT_ADDR="http://localhost:30001"
export VAULT_TOKEN="root"
export VAULT_NAMESPACE="root"
```

### 1. Confirm mounts

```
vault secrets list | grep spiffe
vault auth list | grep spiffe
```

You should see `spiffe/` (secret) and `auth-spiffe/` (auth).

### 2. Inspect the issuer config and roles

```
vault read spiffe/config
vault read spiffe/role/app-a
vault read spiffe/role/app-b
```

Optional discovery/JWKS (useful for non-Vault relying parties):

```
http $VAULT_ADDR/v1/spiffe/.well-known/keys
http $VAULT_ADDR/v1/spiffe/.well-known/openid-configuration
```

OIDC discovery is more relevant when `jwt_oidc_compatibility_mode` is true. This lab leaves it false.

### 3. Mint a JWT-SVID for App A

Minting requires a token that can `create`/`update` `spiffe/role/app-a/mintjwt`. The root token works. After a successful SPIFFE login, the new token’s `spiffe-app-a` policy can mint as well.

**Audience is required on mint.** Use a value that is also allowed on `auth/auth-spiffe/config`.

```
JWT_SVID=$(vault write -format=json \
    spiffe/role/app-a/mintjwt \
    audience=vault | jq -r '.data.token')
echo "$JWT_SVID"
```

Decode the payload (no signature check):

```
echo "$JWT_SVID" | cut -d. -f2 | base64 -d 2>/dev/null | jq
```

Expect claims along these lines:

| Claim | Meaning |
| --- | --- |
| `sub` | `spiffe://example.org/ns/blue/sa/app-a` |
| `aud` | `[ "vault" ]` (whatever you passed to `mintjwt`) |
| `iss` | Issuer for this mount |
| `exp` / `iat` | Lifetime from the role TTL (1h) |
| `jti` | Unique id (`use_jti_claim`) |
| `vault.entity.id` | Entity of the **caller who minted**, not the SPIFFE workload |

The minter’s entity is baked into the JWT. The identity you get **after login** is determined by the SPIFFE auth role (and any matching entity alias), not by that claim.

### 4. Log in with the JWT-SVID

The plugin reads the JWT from the `Authorization` header. That is why the auth backend is tuned with `passthrough_request_headers = ["Authorization"]`.

```
http POST $VAULT_ADDR/v1/auth/auth-spiffe/login \
  Authorization:"Bearer $JWT_SVID" \
  role=app-a
```

curl:

```
curl \
  --header "Authorization: Bearer $JWT_SVID" \
  --request POST \
  --data '{"role": "app-a"}' \
  $VAULT_ADDR/v1/auth/auth-spiffe/login | jq
```

You can pass `"type": "jwt"` in the body to skip auto-detection. Default `auto` prefers a JWT if the Bearer header is present.

A successful response includes a `client_token` with policies `default`, `blue`, and `spiffe-app-a` (plus identity policies if you later attach the alias to the `app_a` entity).

Save the token:

```
export SPIFFE_TOKEN=$(curl -s \
  --header "Authorization: Bearer $JWT_SVID" \
  --request POST \
  --data '{"role": "app-a"}' \
  $VAULT_ADDR/v1/auth/auth-spiffe/login | jq -r '.auth.client_token')
```

### 5. Use the token (and watch client count)

The auth role sets `token_num_uses = 1`. The token is spent by the **first** authenticated API call after login. Use it for a single read:

```
curl \
  --header "X-Vault-Token: $SPIFFE_TOKEN" \
  $VAULT_ADDR/v1/blue/kv/data/app/config | jq
```

You should see `username=demo`, `password=blue`.

That read is what creates a **client** for this identity in the current billing period. Login alone is not enough (same rule as the rest of this lab).

Check activity:

```
http $VAULT_ADDR/v1/sys/internal/counters/activity/monthly "X-Vault-Token: $VAULT_TOKEN"
```

Under `mounts`, expect a new path `auth/auth-spiffe/` if this identity had not already been counted this month.

### 6. App B (mint only)

```
vault write -format=json \
  spiffe/role/app-b/mintjwt \
  audience=vault | jq -r '.data.token'
```

Login with role `app-a` will **fail** (workload id is `/ns/red/sa/app-b`). To complete the loop for App B, add a `vault_spiffe_auth_backend_role` with `workload_id_patterns = ["/ns/red/sa/app-b"]` and policies `red` + `spiffe-app-b`.

## Client counting and entities

SPIFFE login is another auth mount in **root**, so it follows the same rules as Kubernetes and AppRole in this lab:

- Entities and aliases are per namespace. Auth in root means one client across `blue/` and `red/` secret namespaces.
- Vault creates an entity + alias on first SPIFFE login unless you pre-create them.
- This repo pre-creates aliases for AppRole and Kubernetes on `app_a` / `app_b`. It does **not** yet create a SPIFFE alias. The first JWT login therefore shows up as a **new** entity (or a new alias if you attach it later), not as the existing `app_a` entity.
- Alias name for SPIFFE is the workload identity (SPIFFE ID path). To merge with `app_a`, add a `vault_identity_entity_alias` whose `name` matches what the auth method uses and whose `mount_accessor` is the `auth-spiffe` accessor.
- `token_num_uses = 1` does not change *whether* a client is counted; it only limits how many times that token can call the API.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| JWT login denied, audience / JWT-SVID rejected | `audience` on `auth/auth-spiffe/config` is empty or does not include the value used in `mintjwt` |
| Signature / key / `kid` errors | Stale `static_bundle`; fetch `spiffe/trust_bundle/web` and re-apply |
| `Authorization` header ignored | Auth mount not tuned with `passthrough_request_headers = ["Authorization"]` |
| Role not found / workload mismatch | JWT `sub` path does not match `workload_id_patterns` (App B JWT vs App A role) |
| Mint permission denied | Token lacks `spiffe-app-a` / `spiffe-app-b` (or is not root) |
| Second API call fails after SPIFFE login | `token_num_uses = 1` on the auth role |
| `https_web_bundle` fetch fails | Vault listener is HTTP-only in this lab; stay on `profile = static` |
| Provider / resource not found | Vault provider must be 5.12+; Vault image must be Enterprise with SPIFFE plugins |

## What this lab does not do

- No SPIRE / Workload API. Vault is both issuer and relying party.
- No X.509-SVIDs. That needs TLS client certs (`tls_disable` and `tls_disable_client_certs` both false). This cluster is HTTP.
- No live JWKS fetch from `spiffe/trust_bundle/web` into auth (commented in `auth.tf` until TLS exists).
- No SPIFFE auth role or entity alias for App B.
- No pre-created entity alias linking SPIFFE login to the `app_a` entity.

A natural follow-on is to attach a SPIFFE alias to `vault_identity_entity.app_a` so Kubernetes, AppRole, and JWT-SVID logins count as **one** client.
