# Runbook

These are common operations. Sections get filled in as each phase lands.

## Manual steps (unavoidable click-ops, recorded here)

| # | When | What | Why it can't be code |
|---|---|---|---|
| M1 | Phase 2 | Install Xcode CLT and Homebrew | Bootstraps the tool that installs everything else |
| M2 | Phase 2 | `gh auth login` and generating the SSH key | Interactive login and a passphrase only you should know |
| M3 | Phase 2 | Scaleway sign-up, identity check, payment method, owner MFA | Legal and billing identity |
| M4 | Phase 2 | Admin user: first login, change the emailed password, enrol MFA | The user itself is created in code (`infra/bootstrap`), but password change and MFA enrolment are interactive |
| M5 | Phase 2 | Temporary owner API key for the first bootstrap apply | Something has to exist before IaC can authenticate |
| M6 | Phase 3 | (Undone) External-domain TXT and `cloud` NS records at GoDaddy. **Remove them.** | GoDaddy's DNS API isn't available on this account; see ADR 0008 |

Exact steps for each are in the sections below.

## SSH key and git identity (M2)
- The key is `~/.ssh/id_ed25519_github` (ed25519, protected by a passphrase). It is used for both **authentication** and **commit signing**.
- **Passphrase:** stored in NordPass, and also in the macOS Keychain so it unlocks automatically (`UseKeychain yes` in `~/.ssh/config`).
- **Backup:** a copy of the private key is kept as a NordPass Secure Note.
- **Restoring on a new Mac:**
  1. Paste the note into `~/.ssh/id_ed25519_github`.
  2. Run `chmod 600 ~/.ssh/id_ed25519_github`.
  3. Run `ssh-keygen -y -f ~/.ssh/id_ed25519_github > ~/.ssh/id_ed25519_github.pub`.
  4. Recreate `~/.ssh/config`.
  5. Run `ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github`.
- **If the key is lost or compromised:** delete it on GitHub (`gh ssh-key list` / `gh ssh-key delete <id>`), generate a new one, and upload it with `gh ssh-key add` (once for authentication, and again with `--type signing`).
- **Git identity:** the commit email is GitHub's no-reply address (`<id>+<user>@users.noreply.github.com`), so your real email never appears in a public repo's history.
- **Commit signing:** commits are signed with the SSH key (`gpg.format=ssh`). GitHub shows them as **Verified**.

## Scaleway account sign-up and owner hardening (M3)
1. Go to https://console.scaleway.com/register and sign up as an **Individual**, using your personal email. This login is the Organization **owner**.
2. Verify your email, then add a payment method under **Billing → Payment methods**. Complete identity verification if you're asked to.
3. Turn on **MFA** for the owner: click your avatar (top right) → **Account / User account** → **Security** → enable two-factor authentication. Use an authenticator app (NordPass Authenticator works). **Save the recovery codes in NordPass.**
4. Copy the **Organization ID** (Organization settings). It isn't secret, but you'll need it for the CLI profile.
5. Use the owner login only for billing and break-glass from now on.

## First bootstrap apply (M5)
1. As the owner, go to **IAM → API keys → Generate API key**:
   - Bearer: *Myself (IAM user)*
   - Expiration: **1 day**
   - Object Storage preferred project: *default*
   - Description: `bootstrap-temp`
2. In your **own Terminal**, never in a chat, run `scw init -p bootstrap` and paste the access key, secret key and Organization ID when asked. Choose region `fr-par` and zone `fr-par-1`. Don't let it send telemetry or install autocomplete unless you want them.
3. Run the bootstrap with `SCW_PROFILE=bootstrap`: plan, review, apply, then migrate the state into the bucket.
4. Delete the key in the console, and run `scw config profile delete bootstrap`.

## Running OpenTofu locally
Day-to-day work uses the `darragh-admin` CLI profile. The state backend talks S3, so it reads the same Scaleway key from the `AWS_*` variables:
```sh
export SCW_PROFILE=admin
export AWS_ACCESS_KEY_ID=$(scw config get access-key) AWS_SECRET_ACCESS_KEY=$(scw config get secret-key)
cd infra/<stack> && tofu init && tofu plan
```
**Gotcha:** the S3 API only sees buckets in the API key's **preferred Object Storage project**. Every key that touches state must use `platform-mgmt` as its preferred project. Otherwise you get `403 Forbidden` on `HeadObject`.

For `infra/github`, also run `export GITHUB_TOKEN=$(gh auth token)`.

**Shell gotcha:** export `SCW_PROFILE` on its **own line** first. In `export A=x B=$(cmd)`, the `$(cmd)` runs before `A` is exported, so it would read the wrong profile.

### GitHub settings (`infra/github`)
- **Managed as code:** the `protect-main` ruleset, plus the `dev` and `prod` environments. Only `main` can deploy to them, prod needs your approval, and admins can't bypass that.
- **Not managed as code:** secret scanning and push protection. They were enabled once with `gh api -X PATCH repos/darraghobrien13/platform` (`security_and_analysis`). The repository resource itself is deliberately left out of IaC, to avoid any chance of an accidental delete.
- **Emergency (CI is broken and blocks every merge):** temporarily set `enforcement = "disabled"` on the ruleset and apply locally. Fix CI, then re-enable.

### State locking
- Each state file has a `<key>.tflock` object next to it, written with an S3 conditional write.
- A second concurrent run fails with `Error acquiring the state lock … 412 PreconditionFailed`. This was tested on 2026-10-10.
- If a crashed run leaves a stale lock, first confirm nothing is running, then run `tofu force-unlock <LOCK_ID>`.

## Break-glass: changing `infra/bootstrap`
The bootstrap stack manages IAM and projects. Your day-to-day admin key deliberately **cannot** change IAM.
1. Log in to the console as the **owner** (MFA).
2. Create an API key that expires in **1 day**, under IAM → API keys.
3. `export SCW_ACCESS_KEY=... SCW_SECRET_KEY=...` in that terminal only.
4. In `infra/bootstrap`: run `tofu plan`, review it, then run `tofu apply`.
5. Delete the key straight away. Close the terminal.

## Database identities and smoke test
- **Two identities per environment.** Both are IAM applications, because Serverless SQL logs in with an IAM application ID plus the secret of its API key:
  - `app-<env>`: reads and writes rows only. Its login is in Secret Manager as `db-credentials`.
  - `migrate-<env>`: can also change the schema. Its login is in `db-migrate-credentials`. **Only the deploy pipeline uses it.**
- **Reading a login** (with the admin profile; never paste it anywhere):
  ```sh
  P=<env project id>
  ID=$(scw secret secret list project-id=$P name=db-credentials -o json | jq -r '.[0].id')
  scw secret version access secret-id=$ID revision=latest -o json | jq -r .data | base64 -d
  ```
- **Smoke test:** connect as each identity and check that:
  - `migrate` can CREATE TABLE;
  - `app` can do CRUD on that table;
  - `app` gets `permission denied` for CREATE and DROP;
  - then drop the test table.

  Last run: dev, 2026-11-15, all passed. The first connection after idle takes about 3–5s (cold start).
- **Rotation:** the keys rotate automatically every 180 days. The first `infra/bootstrap` apply after the rotation date replaces the key and the secret version; this needs break-glass. Then re-apply `infra/envs/<env>` so the containers get the new `DATABASE_URL`. Each key keeps working for 30 days after its rotation date.

## Deploy
- **Infrastructure:** open a PR that changes `infra/envs` or `infra/modules`.
  1. The `infra` workflow posts plans for dev and prod in the job summary. Review them.
  2. Merge. Dev applies automatically.
  3. **Prod waits.** Go to Actions → the `infra` run → **Review deployments → prod → Approve**, after checking the prod plan.
- **App:** merge a change under `app/`.
  1. The `app` workflow builds the images once, deploys them to dev and smoke-tests them.
  2. Then it waits for your approval for prod, which receives the *same* images, copied rather than rebuilt.
- `infra` applies on `main` only when infrastructure files change. App-only merges don't queue a prod approval.
- **Approving prod:** Actions → the run → **Review deployments** → **tick `prod`** → **Approve and deploy**. A job you don't approve just waits, for up to 30 days, and can be cancelled.
- **Never** run `infra/bootstrap` or `infra/github` in CI. They stay local and break-glass.

## Roll back
- **App:** Actions → **app** → **Run workflow**. Choose the environment, and enter the SHA of an earlier deploy (12+ characters; it's shown in each run summary). That image is redeployed with no rebuild, and the smoke tests run. Prod still needs approval.
  - From a terminal: `gh workflow run app.yml -f env=prod -f ref=<sha>`
- **Infrastructure:** revert the PR (`git revert`, as a new PR) and go through the normal flow. The state bucket is versioned, so a corrupted state can be restored to an earlier object version (owner or admin only).

## View logs
Scaleway sends the logs and metrics of its own products (Serverless Containers, Serverless SQL) to **Cockpit** automatically. This is free at default retention: 7 days for logs, 31 for metrics.
1. Log in to the console as `darragh-admin` and select the project (`platform-dev` or `platform-prod`).
2. Go to **Cockpit → Open dashboards**. Grafana opens, signed in with your Scaleway identity.
3. Open the **Serverless Containers** dashboards, which show request rate, cold starts, CPU and memory. For a container's **logs**, use **Explore → Scaleway Logs** and filter on the container name (`web` or `api`). The dashboard names may differ slightly (verify).
4. Shortcut: in the console, open the container itself (Serverless → Containers → `platform-<env>` → `api`) and use its **Logs** or **Metrics** tab.

Alerts go to the email set in `alert_emails`, through each project's Cockpit alert manager (`infra/modules/environment`).

## Rotate CI keys (every 90 days; each key works for 14 days after its rotation date)
1. Break-glass: in `infra/bootstrap`, run `tofu plan`. It shows `time_rotating.ci_key[...]` replacing the expired keys. Then apply.
2. Push the new keys to GitHub without printing them, using the admin profile:
   ```sh
   K="$(cd infra/bootstrap && tofu output -json ci_keys)"; R=darraghobrien13/platform
   jq -rj '."ci-plan".access_key' <<<"$K" | gh secret set SCW_PLAN_ACCESS_KEY -R $R
   jq -rj '."ci-plan".secret_key' <<<"$K" | gh secret set SCW_PLAN_SECRET_KEY -R $R
   for e in dev prod; do
     jq -rj --arg k ci-$e '.[$k].access_key' <<<"$K" | gh secret set SCW_ACCESS_KEY -R $R --env $e
     jq -rj --arg k ci-$e '.[$k].secret_key' <<<"$K" | gh secret set SCW_SECRET_KEY -R $R --env $e
   done; unset K
   ```
3. Re-run the latest `infra` workflow to confirm the new keys work.

## Rotate the admin API key (`darragh-admin-laptop` expires 2026-12-31)
1. Log in as `darragh-admin`. Under **IAM → API keys → Generate**, choose:
   - Bearer: *Myself*
   - Expiry: 90 days
   - **Preferred Object Storage project: `platform-mgmt`**
   - Description: `darragh-admin-laptop-<yyyymm>`
2. In your own terminal, run `scw init -p admin` and paste the new keys. This overwrites the profile.
3. Check it works: `scw account project list` and, in any stack, `tofu plan`.
4. Delete the old key in the console. Check that `scw iam api-key list` shows only the new one.

## Destroy everything
*Phase 6.*
