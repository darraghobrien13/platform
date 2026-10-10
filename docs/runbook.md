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

## Deploy
*Phase 4.*

## Roll back
*Phase 4/5.*

## View logs
*Phase 3 (Cockpit).*

## Rotate CI keys
*Phase 4.*

## Destroy everything
*Phase 6.*
