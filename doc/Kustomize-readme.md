# Kustomize: A Quick Beginner Guide

## What is it?

**Kustomize combines Kubernetes YAML files into one deployable configuration.** It is built into `kubectl`; you do not need a separate installation.

```text
Service manifests + configuration files
                  |
               Kustomize
                  |
          Combined Kubernetes YAML
                  |
             kubectl apply
                  |
       Kubernetes runs the workloads
```

Kustomize does **not** create a cluster, build Docker images, or run containers itself.

## Four terms to know

| Term | Meaning in this project |
|---|---|
| Manifest | A YAML description of a Kubernetes object, such as a Deployment or Service. |
| Deployment | Tells Kubernetes which image to run and how many copies to maintain. |
| ConfigMap | Stores non-secret configuration used by applications. |
| Kustomization | The file that lists which manifests and configuration files to combine. |

## How this project uses it

Start with [kubernetes/kustomization.yaml](../kubernetes/kustomization.yaml):

- `resources`: lists service manifests, network policies, and the namespace manifest.
- `namespace`: places namespaced objects in `ecomm-lab`.
- `configMapGenerator`: turns checked-in configuration files into ConfigMaps.

Each service has its own readable manifest, such as [frontend/manifest.yaml](../kubernetes/frontend/manifest.yaml). There are currently **no environment overlays**: this is one local lab configuration.

Generated ConfigMaps get a content hash in their names. Kustomize updates matching workload references, so configuration changes can trigger a rollout without manually renaming ConfigMaps.

Exception: the traffic task selector uses a fixed-name ConfigMap; each traffic run starts a fresh Job/Pod.

## Everyday commands

Run these from the project root in Bash or Git Bash.

**First-time setup:** use `bash scripts/install.sh`. It creates the lab cluster and Secrets before applying Kustomize. Applying YAML alone does not perform those setup steps.

**Select the dedicated lab kubeconfig:**

```bash
export KUBECONFIG="$PWD/.local/kubeconfig"
if command -v cygpath >/dev/null; then
  export KUBECONFIG="$(cygpath -m "$KUBECONFIG")"
fi
```

| Action | Command |
|---|---|
| Preview combined YAML; no cluster needed | `kubectl kustomize kubernetes` |
| Compare with the running lab | `kubectl --context kind-ecomm-lab diff -k kubernetes` |
| Deploy or update | `kubectl --context kind-ecomm-lab apply -k kubernetes` |
| Check workloads | `kubectl --context kind-ecomm-lab -n ecomm-lab get pods,services` |
| Watch a frontend update | `kubectl --context kind-ecomm-lab -n ecomm-lab rollout status deployment/frontend --timeout=300s` |

`diff` exits with code **1 when differences exist**; this is not a deployment failure.

## Making a change

1. Edit the relevant source file: for example, change frontend resource limits in its [manifest](../kubernetes/frontend/manifest.yaml).
2. Preview or compare the configuration.
3. Run `apply -k kubernetes`.
4. Check pod health and rollout status. Successful apply means Kubernetes accepted the configuration, not that the application is healthy.

For a new service, add its manifest path to `resources` in the Kustomization.

## Remember

- Use **`-k` for a Kustomize directory**; `-f` applies a regular manifest.
- Apply the whole Kustomization, not individual service files that reference generated ConfigMaps.
- Keep passwords out of ConfigMaps and source files. The installer handles Kubernetes Secrets.
- Removing a resource from the file list does **not** automatically delete its existing Kubernetes object.
- Overlays are optional configurations for environments such as dev and prod. Add them only when you need different settings.

For cluster setup, localhost access, and cleanup, see the [main README](../README.md).
