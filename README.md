# project-atmos-k8s

Helm chart for **Project Atmos** (React frontend, FastAPI backend, MongoDB, Redis) on Amazon EKS.

| Repository | Responsibility |
|---|---|
| `project-atmos-dev` | Application, Docker, CI/CD |
| `project-atmos-k8s` | Helm chart (this repo) |
| `project-atmos-iac` | AWS infrastructure (Terraform) |

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

## Platform (installed once per cluster, not by this chart)

The workflow `.github/workflows/platform.yml` installs: namespaces `dev` and `prod`, Gateway API CRDs, AWS Load Balancer Controller (Gateway API enabled), the `aws-alb` GatewayClass and External Secrets Operator. Run it by hand: Actions -> Platform -> Run workflow, then approve. Run it again after every new cluster. Versions are set at the top of the file.

It runs in the GitHub Environment `platform` (needs approval) with the variable `AWS_GITHUB_ACTIONS_ROLE_ARN` (cluster admin role from `project-atmos-iac`).

## Deploy

The workflow `.github/workflows/cd.yml` deploys to `dev`. It starts when `project-atmos-dev` pushes new images (a `deploy` event with the image tag), or by hand (Actions -> CD -> Run workflow, enter a tag like `v1.0.0-a1b2c3`).

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
