# f5xc-k8s-site

This package tracks the upstream manifest for F5 Distributed Cloud Kubernetes
Site, but with modifications to enable 3 vp-manager instances for high-availability
and site-mesh use.

## Usage

1. Fetch a copy of this package into your local repository

   ```shell
   kpt pkg get https://github.com/memes/proteus-wip/f5xc-k8s-site[@VERSION] my-site
   ```

2. Apply any local customizations

   E.g. to apply a consistent set of annotations

   ```shell
   kpt fn eval my-site --image gcr.io/kpt-fn/set-annotations:v0.1.4 -- example.com/purpose=site-mesh-gateway
   ```

3. Commit the local copy to source control

4. Apply the changes to a cluster

   ```shell
   kpt live init my-site
   kpt live apply my-site --reconcile-timeout=2m --output=table
   ```

## Kustomize

The `upstream` folder includes a `kustomization.yaml` file for use with `kustomize`;
just include `my-site/upstream` as a resource in an overlay `folder.
