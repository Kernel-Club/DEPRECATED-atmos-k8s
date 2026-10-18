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
scripts/nip-host.sh    builds the <prefix>.<alb-ip>.nip.io host
```

## What the chart creates

- **backend / frontend**: Deployments + ClusterIP Services (names `atmos-backend`, `atmos-frontend`).
- **mongodb**: StatefulSet with an EBS volume, root user from the Secret.
- **redis**: Deployment, no persistence (cache only).
- **ExternalSecret** `atmos-secrets`: filled from AWS Secrets Manager (`project-atmos/<env>/openweather-api-key`, `project-atmos/<env>/mongodb`) by External Secrets Operator, plus a namespaced `SecretStore`.
- **Gateway API** for the AWS ALB: `Gateway`, `HTTPRoute` (`/api` -> backend, `/` -> frontend), `LoadBalancerConfiguration`, `TargetGroupConfiguration`.

## Needs from the platform (installed once, not by this chart)

Namespaces `dev` and `prod`, External Secrets Operator, AWS Load Balancer Controller with Gateway API enabled, Gateway API CRDs and the `aws-alb` GatewayClass (or set `gateway.createGatewayClass=true`).

## Deploy

CD in `project-atmos-dev` does this; by hand:

```bash
helm upgrade --install atmos charts/atmos -n dev -f charts/atmos/values-dev.yaml \
  --set backend.image.tag=dev-v1.0.0-abc123 \
  --set frontend.image.tag=dev-v1.0.0-abc123 \
  --atomic --wait
```

Image tags have no default: rendering fails without them.

## nip.io domain

The ALB address is only known after it is created, so CD deploys first, then runs
`scripts/nip-host.sh <namespace> atmos <prefix>` and sets `gateway.host`:

- dev: `http://atmos-dev.<ip>.nip.io`
- prod: `http://atmos.<ip>.nip.io`

Without `gateway.host` the route matches any host, so the app also works on the ALB DNS name. After a new cluster (new ALB) just run CD again.

## Without AWS (kind / minikube)

```bash
kubectl create secret generic atmos-secrets -n dev \
  --from-literal=openweather-api-key=KEY \
  --from-literal=mongodb-username=atmos \
  --from-literal=mongodb-password=pass
helm upgrade --install atmos charts/atmos -n dev \
  --set backend.image.tag=... --set frontend.image.tag=... \
  --set secrets.externalSecrets.enabled=false --set gateway.enabled=false
```

## Checks

```bash
helm lint charts/atmos --set backend.image.tag=x --set frontend.image.tag=x
helm template atmos charts/atmos -f charts/atmos/values-prod.yaml --set backend.image.tag=x --set frontend.image.tag=x
```
