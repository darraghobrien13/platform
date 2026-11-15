# 0008. Use Scaleway's built-in URLs, not a custom domain (for now)

- Status: Accepted
- Date: 2026-11-08
- Supersedes: the DNS part of [0006](0006-environments-region-dns.md)

## Context
ADR 0006 planned to use `dev.`/`app.darragh.email`. The domain is registered at GoDaddy and carries live **Google Workspace mail**, so in Phase 3 we delegated only a subdomain to Scaleway:
- `darragh.email` was registered in Scaleway as an *external domain* and validated with a TXT record.
- A `cloud.darragh.email` zone was created in Scaleway.
- Two NS records were added at GoDaddy.

That worked for a while. Then Scaleway deleted the external domain, and our zone with it. Their rule is that if the external-domain process (which includes **pointing the whole domain's nameservers at Scaleway**) isn't completed within **14 days**, the domain is removed from their DNS. Delegating only a subdomain doesn't count as completing the process. The dev URLs stopped resolving. Everything else was unaffected.

## Decision
Serve every environment on **Scaleway's built-in HTTPS endpoints** (`https://<namespace>-<service>.functions.fnc.fr-par.scw.cloud`).
- They come with managed TLS and need no DNS.
- The `infra/dns` stack and its state were removed.
- The `service` module no longer creates DNS records or custom-domain bindings.

The `web` service forwards `/api/*` to the `api` service, so the browser only ever talks to one origin. This means:
- **no CORS** is needed;
- **only `web` needs to know where `api` is**. Without custom domains, each container's URL only exists after it's created. If `web` and `api` each needed the other's URL, they'd form a dependency cycle.

## Alternatives considered
| Option | Why not now |
|---|---|
| Move all of `darragh.email`'s DNS to Scaleway, with the Workspace MX/SPF records copied into code | It would put live personal email on a learning project's DNS. This is still possible later. |
| Buy a cheap domain registered at Scaleway, used only for this project (about €6–12/year, verify) | **The preferred upgrade path.** It's native to Scaleway, so the external-domain rules don't apply. Deferred until a nice URL is actually needed. |
| Cloudflare for the subdomain | Its free plan can't host just a subdomain; the whole zone would have to move. |

## Consequences
- The URLs are long and auto-generated. They're stable as long as the namespace isn't recreated. Recreating it changes them.
- **Adding a custom domain later:** add a `scaleway_domain_record` and a `scaleway_container_domain` to the `service` module (see git history before this ADR) for a domain that Scaleway hosts fully.
- **Lesson:** "subdomain delegation" for an external domain isn't a supported long-term setup on Scaleway.
- **GoDaddy cleanup (manual):** remove the `cloud` NS records and the `_scaleway-challenge` TXT record.

## Sources
- [Scaleway: add an external domain (48-hour TXT and 14-day completion rules)](https://www.scaleway.com/en/docs/domains-and-dns/how-to/add-external-domain/)
- [Scaleway: manage external domain](https://www.scaleway.com/en/docs/domains-and-dns/how-to/manage-external-domain.md)
