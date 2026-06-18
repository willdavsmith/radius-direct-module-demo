# Direct Module Support for Recipes — Demo

A demo of [Radius **direct module support for recipes**](https://github.com/radius-project/radius/pull/12109): pointing a recipe's `recipeLocation` straight at a **standard, off-the-shelf Terraform Registry module** — no Radius-specific wrapping required.

Today, every module used as a Radius recipe must be wrapped to add a `context` input variable and a structured `result` output. This blocks direct use of community modules (Terraform Registry, Azure Verified Modules) and adds maintenance overhead. With direct module support, a platform engineer points `recipeLocation` at a plain module, and Radius:

1. resolves `{{context.*}}` expressions declared in the recipe `parameters`,
2. runs the module through the existing Terraform (or Bicep) driver, and
3. maps the module's plain outputs onto resource properties via a new `outputs` field.

Existing wrapped recipes keep working unchanged.

## What this demo shows

The recipe points directly at the public Terraform Registry module [`terraform-iaac/deployment/kubernetes`](https://registry.terraform.io/modules/terraform-iaac/deployment/kubernetes/latest), pinned to a specific version. It is an ordinary community module — **no `context` variable, no `result` output** — with `name` / `namespace` / `image` inputs and `name` / `namespace` outputs.

The platform engineer wires it to a custom resource type (`Demo.Kubernetes/deployments`) with a recipe pack ([`demo/platform.bicep`](demo/platform.bicep)):

```bicep
'Demo.Kubernetes/deployments': {
  recipeKind: 'terraform'
  recipeLocation: 'terraform-iaac/deployment/kubernetes:1.4.6'   // <source>:<version>
  parameters: {
    name: '{{context.resource.name}}'                  // resolved per-resource
    namespace: '{{context.runtime.kubernetes.namespace}}'
    image: '{{context.resource.properties.image}}'     // resolved from the resource below
  }
  outputs: {
    deploymentName: 'name'                             // resource property <- module output
    namespace: 'namespace'
  }
}
```

A developer then deploys an ordinary resource ([`demo/app.bicep`](demo/app.bicep)) with no module details at all — just the image:

```bicep
resource deployment 'Demo.Kubernetes/deployments@2023-10-01-preview' = {
  name: 'demo-redis'
  properties: {
    environment: environment
    application: app.id
    image: 'redis:7-alpine'
  }
}
```

Radius pins and fetches the registry module at `1.4.6`, resolves the parameter expressions (including reading `image` back off the resource), runs the module, and populates `deployment.properties.deploymentName` and `deployment.properties.namespace` from the module outputs (note the rename: module output `name` → property `deploymentName`).

## Repository structure

```text
├── radius/                                    # Git submodule → radius-project/radius
│                                              #   @ willdavsmith/recipe-direct-module-support (the feature branch)
├── types/
│   └── deployments.yaml                       # Custom resource type Demo.Kubernetes/deployments
├── demo/
│   ├── bicepconfig.json                       # Bicep extensions: local radius-extension.tgz + deployments-extension.tgz
│   ├── platform.bicep                         # Recipe pack (direct registry module) + environment
│   └── app.bicep                              # Developer-facing resource
└── .github/
    ├── actions/radius-direct-module-e2e/      # Composite E2E action (install → setup → deploy → verify)
    └── workflows/
        ├── e2e-kind.yaml                       # E2E on kind (push / PR / dispatch)
        └── e2e-k3d.yaml                        # E2E on k3d (dispatch)
```

> The `radius` submodule is pinned to the feature branch. The E2E builds **two** control-plane images from it: `applications-rp` (serves `Radius.Core/recipePacks`, including the new `outputs` field) and `dynamic-rp` (runs the recipe engine — direct-module parsing, parameter resolution, and outputs mapping).

## How the E2E works

The [`radius-direct-module-e2e`](.github/actions/radius-direct-module-e2e/action.yaml) composite action:

1. builds the `rad` CLI and the `applications-rp` + `dynamic-rp` images from the `radius` submodule;
2. installs Radius from the worktree Helm chart, overriding both images (`--set rp.image/tag` and `--set dynamicrp.image/tag`);
3. **[PE]** registers the `Demo.Kubernetes/deployments` type, builds the Bicep extensions (the **Radius core** extension from the submodule — so it carries the new `outputs` field — plus the demo type's extension), and deploys `platform.bicep` (recipe pack + environment);
4. **[Developer]** deploys `app.bicep`;
5. **verifies** the module ran and the outputs were mapped:
   - `rad resource show` reports `properties.deploymentName` and `properties.namespace` populated from the module outputs,
   - `deploymentName == demo-redis` proves the `{{context.*}}` expressions resolved and the module's `name` output was mapped back,
   - `kubectl` confirms the Redis `Deployment` is available in the cluster.

The Terraform Registry module (and the `hashicorp/kubernetes` provider it needs) are fetched in-cluster by the recipe engine, so the cluster needs outbound network access to `registry.terraform.io` — kind and k3d nodes have this by default. The Redis image the module deploys is **side-loaded** into the cluster so that container pull is hermetic (Docker Hub is rate-limited anonymously in CI).

> Because the module comes from the public Terraform Registry (not this repo), this repository does **not** need to be public for the demo to run. The `radius` submodule is fetched from the public `radius-project/radius` repo.

### Why the Radius Bicep extension is built from source

The `outputs` field on `Radius.Core/recipePacks` is **new in this feature** and is not yet in the published `br:biceptypes.azurecr.io/radius` Bicep types. So [`demo/bicepconfig.json`](demo/bicepconfig.json) points the `radius` extension at a **local `radius-extension.tgz`** that `make radius-extension` generates from the submodule's OpenAPI specs (`make generate-bicep-types` → `bicep publish-extension`). Once these types are released, the demo can switch `radius` back to the published `br:` reference.

## Version pinning

Terraform Registry modules are referenced by a `<namespace>/<name>/<provider>` address (e.g. `terraform-iaac/deployment/kubernetes`) plus a separate `version`, not a URL. This feature pins the version with a `<source>:<version>` convention in `recipeLocation`, mirroring how Bicep/OCI recipes embed the version in the image tag (see [radius-project/radius#12086](https://github.com/radius-project/radius/issues/12086)):

```bicep
recipeLocation: 'terraform-iaac/deployment/kubernetes:1.4.6'   // <source>:<version>
```

Radius splits this into the module `source` and `version` fields of the generated `main.tf.json`. The split is collision-safe: only a colon in the final path segment is treated as a version, so a registry `host:port` (e.g. `my.registry.com:8443/ns/name/aws`) and `://` URL sources (Git/HTTP/OCI) are left untouched.

## Quick start (local)

### Prerequisites

- [kind](https://kind.sigs.k8s.io/) or [k3d](https://k3d.io/)
- Go (matching `radius/go.mod`) and Docker, to build the control-plane images
- Node.js (matching `radius/.node-version`), [`yq`](https://github.com/mikefarah/yq), and the [Bicep CLI](https://github.com/Azure/bicep/releases) — to generate the Radius core Bicep extension from the submodule (see [above](#why-the-radius-bicep-extension-is-built-from-source))

### 1. Clone with submodules

```bash
git clone --recurse-submodules https://github.com/willdavsmith/radius-direct-module-demo.git
cd radius-direct-module-demo
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
rad deploy platform.bicep
```

### 4. Developer deploy

```bash
rad deploy app.bicep
rad resource show Demo.Kubernetes/deployments demo-redis
# properties.deploymentName and properties.namespace are populated from the module outputs
```
