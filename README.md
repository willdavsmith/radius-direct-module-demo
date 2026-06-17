# Direct Module Support for Recipes — Demo

A demo of [Radius **direct module support for recipes**](https://github.com/radius-project/radius/pull/12109): pointing a recipe's `recipeLocation` straight at a **standard, off-the-shelf Terraform module** — no Radius-specific wrapping required.

Today, every module used as a Radius recipe must be wrapped to add a `context` input variable and a structured `result` output. This blocks direct use of community modules (Terraform Registry, Azure Verified Modules) and adds maintenance overhead. With direct module support, a platform engineer points `recipeLocation` at a plain module, and Radius:

1. resolves `{{context.*}}` expressions declared in the recipe `parameters`,
2. runs the module through the existing Terraform (or Bicep) driver, and
3. maps the module's plain outputs onto resource properties via a new `outputs` field.

Existing wrapped recipes keep working unchanged.

## What this demo shows

A standard Terraform module ([`modules/redis`](modules/redis)) deploys Redis to Kubernetes. It has **no `context` variable and no `result` output** — it is just a normal module with `name` / `namespace` / `port` variables and `host` / `port` outputs.

The platform engineer wires it to a custom resource type (`Demo.Datastores/redisCaches`) with a recipe pack ([`demo/platform.bicep`](demo/platform.bicep)):

```bicep
'Demo.Datastores/redisCaches': {
  recipeKind: 'terraform'
  recipeLocation: moduleTemplatePath          // git:: URL of the plain module
  parameters: {
    name: '{{context.resource.name}}'         // resolved per-resource
    namespace: '{{context.runtime.kubernetes.namespace}}'
    port: 6379
  }
  outputs: {
    endpoint: 'host'                          // resource property <- module output
    port: 'port'
  }
}
```

A developer then deploys an ordinary resource ([`demo/app.bicep`](demo/app.bicep)) with no module details at all:

```bicep
resource cache 'Demo.Datastores/redisCaches@2023-10-01-preview' = {
  name: 'demo-redis'
  properties: {
    environment: environment
    application: app.id
  }
}
```

Radius resolves the parameter expressions, runs the module, and populates `cache.properties.endpoint` and `cache.properties.port` from the module outputs (note the rename: module output `host` → property `endpoint`).

## Repository structure

```text
├── radius/                                    # Git submodule → radius-project/radius
│                                              #   @ willdavsmith/recipe-direct-module-support (the feature branch)
├── modules/
│   └── redis/                                 # STANDARD Terraform module — no Radius conventions
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── types/
│   └── redisCaches.yaml                       # Custom resource type Demo.Datastores/redisCaches
├── demo/
│   ├── bicepconfig.json                       # Bicep extension configuration
│   ├── platform.bicep                         # Recipe pack (direct module) + environment
│   └── app.bicep                              # Developer-facing resource
└── .github/
    ├── actions/radius-direct-module-e2e/      # Composite E2E action (install → setup → deploy → verify)
    └── workflows/
        ├── e2e-kind.yaml                       # Hermetic E2E on kind (push / PR / dispatch)
        └── e2e-k3d.yaml                        # Hermetic E2E on k3d (dispatch)
```

> The `radius` submodule is pinned to the feature branch. The E2E builds **two** control-plane images from it: `applications-rp` (serves `Radius.Core/recipePacks`, including the new `outputs` field) and `dynamic-rp` (runs the recipe engine — direct-module parsing, parameter resolution, and outputs mapping).

## How the E2E works

The [`radius-direct-module-e2e`](.github/actions/radius-direct-module-e2e/action.yaml) composite action:

1. builds the `rad` CLI and the `applications-rp` + `dynamic-rp` images from the `radius` submodule;
2. installs Radius from the worktree Helm chart, overriding both images (`--set rp.image/tag` and `--set dynamicrp.image/tag`);
3. **[PE]** registers the `Demo.Datastores/redisCaches` type, builds the Bicep extensions (the **Radius core** extension from the submodule — so it carries the new `outputs` field — plus the demo type's extension), and deploys `platform.bicep` (recipe pack + environment);
4. **[Developer]** deploys `app.bicep`;
5. **verifies** the module ran and the outputs were mapped:
   - `rad resource show` reports `properties.endpoint` and `properties.port` populated from the module outputs,
   - the `endpoint` value (`demo-redis.<namespace>.svc.cluster.local`) proves the `{{context.*}}` expressions resolved,
   - `kubectl` confirms the Redis `Deployment` and `Service` exist in the cluster.

The kind and k3d workflows are **hermetic**: the control-plane images are side-loaded into the cluster, and the Terraform module is fetched over `git::` from this repo at the workflow SHA.

> **Note:** for the in-cluster Terraform fetch to succeed, this repository must be **public** (or you must configure Radius Git credentials for the module source). The module is fetched via `git::https://github.com/<org>/<repo>.git//modules/redis?ref=<sha>`.

### Why the Radius Bicep extension is built from source

The `outputs` field on `Radius.Core/recipePacks` is **new in this feature** and is not yet in the published `br:biceptypes.azurecr.io/radius` Bicep types. So [`demo/bicepconfig.json`](demo/bicepconfig.json) points the `radius` extension at a **local `radius-extension.tgz`** that `make radius-extension` generates from the submodule's OpenAPI specs (`make generate-bicep-types` → `bicep publish-extension`). Once these types are released, the demo can switch `radius` back to the published `br:` reference.

## Quick start (local)

### Prerequisites

- [kind](https://kind.sigs.k8s.io/) or [k3d](https://k3d.io/)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- Go (matching `radius/go.mod`) and Docker, to build the control-plane images
- Node.js (matching `radius/.node-version`), [`yq`](https://github.com/mikefarah/yq), and the [Bicep CLI](https://github.com/Azure/bicep/releases) — to generate the Radius core Bicep extension from the submodule (see [above](#why-the-radius-bicep-extension-is-built-from-source))

### 1. Clone with submodules

```bash
git clone --recurse-submodules https://github.com/<org>/061726-direct-module.git
cd 061726-direct-module
```

### 2. Build + install Radius from the feature branch

```bash
cd radius
make build-binaries && sudo cp dist/linux_amd64/release/rad /usr/local/bin/rad
make docker-build-applications-rp DOCKER_REGISTRY=localhost DOCKER_TAG_VERSION=dev
make docker-build-dynamic-rp      DOCKER_REGISTRY=localhost DOCKER_TAG_VERSION=dev
# load localhost/applications-rp:dev and localhost/dynamic-rp:dev into your cluster, then:
rad install kubernetes --reinstall --chart deploy/Chart \
  --set rp.image=localhost/applications-rp --set rp.tag=dev \
  --set dynamicrp.image=localhost/dynamic-rp --set dynamicrp.tag=dev
cd ..
```

### 3. Platform-engineer setup

```bash
rad group create default
rad env create default --preview --group default
rad workspace create kubernetes default --context "$(kubectl config current-context)" --group default
rad workspace switch default && rad env switch default --preview

make setup   # registers the resource type + builds the Bicep extensions
             # (generates the Radius core types from the submodule — slow on first run)
cd demo
rad deploy platform.bicep \
  -p moduleTemplatePath='git::https://github.com/<org>/061726-direct-module.git//modules/redis?ref=main'
```

### 4. Developer deploy

```bash
rad deploy app.bicep
rad resource show Demo.Datastores/redisCaches demo-redis
# properties.endpoint and properties.port are populated from the module outputs
```

## Terraform Registry modules and versions

Terraform Registry modules are not URLs and require a separate `version` argument. This feature uses a `<source>:<version>` convention in `recipeLocation`, mirroring how Bicep/OCI recipes embed the version in the image tag (see [radius-project/radius#12086](https://github.com/radius-project/radius/issues/12086)):

```bicep
'Demo.Datastores/redisCaches': {
  recipeKind: 'terraform'
  recipeLocation: 'terraform-aws-modules/rds/aws:6.1.0'   // <source>:<version>
  parameters: { /* ... */ }
  outputs:    { /* ... */ }
}
```

Radius splits this into the module `source` and `version` fields of the generated `main.tf.json`. The split is collision-safe: only a colon in the final path segment is treated as a version, so a registry `host:port` (e.g. `my.registry.com:8443/ns/name/aws`) and `://` URL sources are left untouched.

> Registry modules require the cluster to have network egress to the registry, so this path is exercised on cloud clusters rather than the hermetic kind/k3d workflows here.
