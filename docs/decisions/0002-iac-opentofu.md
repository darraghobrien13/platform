# 0002. Infrastructure as Code: OpenTofu

- Status: Accepted
- Date: 2026-10-10

## Context
All infrastructure must be defined as code with open-source tools, with no click-ops. The owner wants transferable skills and is also building up TypeScript.

## Decision
Use **OpenTofu**, the open-source Terraform fork (MPL-2.0), with the `scaleway/scaleway` provider. Pin a 1.12.x release; the exact version is checked in Phase 2 (verify).

**Remote state** lives in a Scaleway Object Storage bucket, accessed through OpenTofu's `s3` backend:
- `use_lockfile = true` turns on native locking. OpenTofu 1.10+ uses S3 conditional writes for this, and Scaleway supports `If-None-Match`. We will prove it works in Phase 2 by running two plans at once.
- Bucket versioning is on, so an earlier state can be recovered.
- There is one state file per stack and environment, for example `envs/dev/terraform.tfstate`.

**Bootstrap:** a small `bootstrap/` stack creates the state bucket using *local* state. Its state is then migrated into the bucket. This "chicken and egg" step is the only stack that ever runs with local state.

## Alternatives considered
- **Terraform (HashiCorp):** nearly identical day to day, but under the BSL licence, not open source. Skills move both ways, so nothing is lost by choosing OpenTofu.
- **Pulumi (TypeScript):** real code for infrastructure, with loops, types and unit tests, and extra TypeScript practice. It lost because it is less common in job specs and has a smaller pool of examples. The app already gives plenty of TypeScript practice.
- **Ansible:** a configuration-management tool, not a cloud provisioner. It is unneeded while there are no VMs.

## Consequences
- State files and `*.tfvars` files that contain secrets are **never** committed. `.gitignore` and secret scanning are set up in Phase 2.
- Every `tofu apply` is preceded by a reviewed `tofu plan`.
- Stacks are split by environment so that dev changes cannot touch prod state.
- Moving region later is mostly a variable change plus a data migration.

## Sources
- [OpenTofu (release history)](https://en.wikipedia.org/wiki/OpenTofu)
- [OpenTofu 1.10 native S3 locking](https://oneuptime.com/blog/post/2026-03-20-native-s3-state-locking-opentofu-1-10/markdown)
- [Scaleway Object Storage conditional writes](https://www.scaleway.com/en/docs/object-storage/api-cli/using-conditional-writes/)
