# Runbook

These are common operations. Sections get filled in as each phase lands.

## Manual steps (unavoidable click-ops, recorded here)

| # | When | What | Why it can't be code |
|---|---|---|---|
| M1 | Phase 2 | Install Xcode CLT and Homebrew | Bootstraps the tool that installs everything else |
| M2 | Phase 2 | `gh auth login` and generating the SSH key | Interactive login and a passphrase only you should know |
| M3 | Phase 2 | Scaleway sign-up, identity check, payment method, owner MFA | Legal and billing identity |
| M4 | Phase 2 | Create the admin IAM user and its MFA | The provider can't create password users; MFA enrolment is interactive |
| M5 | Phase 2 | Billing alerts | Set via console or CLI; there is no OpenTofu resource |

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
