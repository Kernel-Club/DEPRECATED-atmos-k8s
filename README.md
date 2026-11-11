# DEPRECATED-atmos-k8s

> [!WARNING]
> **DEPRECATED — not maintained.** This repository is part of the cloud phase of Atmos (AWS EKS), finished on 2026-11-04.
> It is no longer developed or supported, but the code still works and can deploy the cloud infrastructure again
> (see [Deploy again](#deploy-again)). It stays a visible part of the project and shows what was used for the cloud solution. Active repositories: `atmos-dev` (application), `atmos-ansible`, `atmos-jenkins`, `atmos-k8s` (on-premise).
> Names such as `project-atmos-*` and `project_atmos` in the code and in AWS are legacy names and are kept on purpose.

Helm chart for **Atmos** (React frontend, FastAPI backend, MongoDB, Redis) on Amazon EKS.

| Repository | Responsibility |
|---|---|
| [`atmos-dev`](https://github.com/Kernel-Club/atmos-dev) | Application, Docker, CI/CD |
| `DEPRECATED-atmos-k8s` | Helm chart (this repo) |
| [`DEPRECATED-atmos-iac`](https://github.com/Kernel-Club/DEPRECATED-atmos-iac) | AWS infrastructure (Terraform) |

## Layout

```text
charts/atmos/
  Chart.yaml
  values.yaml          defaults
  values-dev.yaml      namespace dev
  values-prod.yaml     namespace prod
  templates/           backend, frontend, mongodb, redis, externalsecret, gateway
```

## What the chart creates

- **backend / frontend**: Deployments + ClusterIP Services (names `atmos-backend`, `atmos-frontend`).
- **mongodb**: StatefulSet with an EBS volume, root user from the Secret.
- **redis**: Deployment, no persistence (cache only).
- **ExternalSecret** `atmos-secrets`: filled from AWS Secrets Manager (`project-atmos/<env>/openweather-api-key`, `project-atmos/<env>/mongodb`) by External Secrets Operator, plus a namespaced `SecretStore`.
- **Gateway API** for the AWS ALB: `Gateway`, `HTTPRoute` (`/api` -> backend, `/` -> frontend), `LoadBalancerConfiguration`, `TargetGroupConfiguration`.

## Platform (part of the infrastructure, not of this chart)

What the chart expects from the cluster is created by Terraform in `DEPRECATED-atmos-iac` (`modules/platform`), in the same `apply` as the cluster: namespaces `dev` and `prod`, default StorageClass `gp3`, Gateway API CRDs, AWS Load Balancer Controller (Gateway API enabled), the `aws-alb` GatewayClass, External Secrets Operator and the RBAC that lets the deploy roles manage the chart's CRDs. This repository only deploys the app and has no cluster admin rights.

## Deploy again

1. Create the cluster from [`DEPRECATED-atmos-iac`](https://github.com/Kernel-Club/DEPRECATED-atmos-iac#deploy-again). Its deploy roles must trust this repository: set the default of `github_repo` there to `DEPRECATED-atmos-k8s` before the `apply`, otherwise the workflow cannot log in to AWS.
2. Keep the organization variable `PROJECT_NAME=project-atmos` (legacy name): it gives the cluster name and the image names.
3. `atmos-dev` sends the `deploy` event to the legacy name `project-atmos-k8s`, which works through the GitHub redirect. If the deploy does not start, run it by hand: Actions → CD → Run workflow, `image_tag` like `v1.0.0-a1b2c3`.

## Deploy

The workflow `.github/workflows/cd.yml` deploys to `dev`. It starts when `atmos-dev` pushes new images (a `deploy` event with the image tag), or by hand (Actions -> CD -> Run workflow, enter a tag like `v1.0.0-a1b2c3`).

It runs in the GitHub Environment `development`, which holds the variable `AWS_GITHUB_ACTIONS_ROLE_ARN`. Organization variables used: `AWS_REGION`, `PROJECT_NAME`, `DOCKERHUB_NAMESPACE`. The cluster name is `<PROJECT_NAME>-eks`, the images are `<DOCKERHUB_NAMESPACE>/<PROJECT_NAME>-backend` and `-frontend`.

By hand (also for `prod`, which has no workflow yet): the chart has no defaults for images, region and secret prefix, so put them in a local file (ignored by git):

```yaml
# values-local.yaml
backend:
  image: {repository: <namespace>/<project>-backend, tag: v1.0.0-a1b2c3}
frontend:
  image: {repository: <namespace>/<project>-frontend, tag: v1.0.0-a1b2c3}
secrets:
  externalSecrets:
    remotePrefix: <project>
    store: {region: <region>}
```

```bash
helm upgrade --install atmos charts/atmos -n dev -f charts/atmos/values-dev.yaml -f values-local.yaml --atomic --wait
```

Rendering fails if one of these values is missing.

## Without AWS (kind / minikube)

```bash
kubectl create secret generic atmos-secrets -n dev \
  --from-literal=openweather-api-key=KEY \
  --from-literal=mongodb-username=atmos \
  --from-literal=mongodb-password=pass
helm upgrade --install atmos charts/atmos -n dev \
  -f values-local.yaml \
  --set secrets.externalSecrets.enabled=false --set gateway.enabled=false
```

## Checks

```bash
helm lint charts/atmos -f values-local.yaml
helm template atmos charts/atmos -f charts/atmos/values-prod.yaml -f values-local.yaml
```
