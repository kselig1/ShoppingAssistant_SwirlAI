#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-2"
CLUSTER_ARN="arn:aws:ecs:us-east-2:912988925636:cluster/ShoppingAssistant"
FE_SERVICE="amazon-fe-service-5kqdz64x"
BE_SERVICE="amazon-be-service-x70xzpow"

OUTDIR="docs/aws-snapshot/$(date +%Y-%m-%d)"
mkdir -p "$OUTDIR"/{ecs,elbv2,ec2,iam,logs,secrets,summary,tmp}

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need aws
if command -v jq >/dev/null 2>&1; then HAS_JQ=1; else HAS_JQ=0; fi

awsj() {
  # awsj <outfile> <aws ...>
  local outfile="$1"; shift
  aws --region "$REGION" "$@" > "$outfile"
  if [[ "$HAS_JQ" == "1" ]]; then
    jq -S . "$outfile" > "${outfile}.sorted" && mv "${outfile}.sorted" "$outfile"
  fi
}

echo "== Identity =="
awsj "$OUTDIR/summary/whoami.json" sts get-caller-identity

echo "== ECS Cluster & Services =="
awsj "$OUTDIR/ecs/cluster.json" ecs describe-clusters \
  --clusters "$CLUSTER_ARN" --include CONFIGURATIONS SETTINGS STATISTICS TAGS

awsj "$OUTDIR/ecs/services.json" ecs describe-services \
  --cluster "$CLUSTER_ARN" --services "$FE_SERVICE" "$BE_SERVICE" --include TAGS

# Extract task definition ARNs
if [[ "$HAS_JQ" == "1" ]]; then
  FE_TD=$(jq -r '.services[] | select(.serviceName=="'"$FE_SERVICE"'") | .taskDefinition' "$OUTDIR/ecs/services.json")
  BE_TD=$(jq -r '.services[] | select(.serviceName=="'"$BE_SERVICE"'") | .taskDefinition' "$OUTDIR/ecs/services.json")
else
  # fallback (less robust)
  FE_TD=$(python - <<'PY'
import json
d=json.load(open("docs/aws-snapshot/"+__import__("datetime").date.today().isoformat()+"/ecs/services.json"))
print([s["taskDefinition"] for s in d["services"] if s["serviceName"]=="amazon-fe-service-5kqdz64x"][0])
PY
)
  BE_TD=$(python - <<'PY'
import json
d=json.load(open("docs/aws-snapshot/"+__import__("datetime").date.today().isoformat()+"/ecs/services.json"))
print([s["taskDefinition"] for s in d["services"] if s["serviceName"]=="amazon-be-service-x70xzpow"][0])
PY
)
fi

echo "== Task Definitions =="
awsj "$OUTDIR/ecs/taskdef-frontend.json" ecs describe-task-definition --task-definition "$FE_TD" --include TAGS
awsj "$OUTDIR/ecs/taskdef-backend.json"  ecs describe-task-definition --task-definition "$BE_TD" --include TAGS

echo "== Networking (subnets/SGs/VPC) from Services =="
# Pull network config + LB target groups from service descriptions
if [[ "$HAS_JQ" == "1" ]]; then
  jq -r '
    .services[] |
    {
      serviceName,
      launchType,
      platformVersion,
      desiredCount,
      enableExecuteCommand,
      networkConfiguration: .networkConfiguration.awsvpcConfiguration,
      loadBalancers,
      serviceRegistries
    }' "$OUTDIR/ecs/services.json" > "$OUTDIR/summary/services-network-and-lb.json"
fi

# Collect referenced subnet IDs + SG IDs
SUBNETS=()
SGS=()
TGS=()
LBS=()

if [[ "$HAS_JQ" == "1" ]]; then
  mapfile -t SUBNETS < <(jq -r '.services[].networkConfiguration.awsvpcConfiguration.subnets[]?' "$OUTDIR/ecs/services.json" | sort -u)
  mapfile -t SGS     < <(jq -r '.services[].networkConfiguration.awsvpcConfiguration.securityGroups[]?' "$OUTDIR/ecs/services.json" | sort -u)
  mapfile -t TGS     < <(jq -r '.services[].loadBalancers[].targetGroupArn?' "$OUTDIR/ecs/services.json" | sort -u)
else
  echo "jq not found; skipping auto-collection of subnet/sg/tg ids. Install jq for best results."
fi

if [[ "${#TGS[@]}" -gt 0 ]]; then
  echo "== ELBv2 Target Groups =="
  awsj "$OUTDIR/elbv2/target-groups.json" elbv2 describe-target-groups --target-group-arns "${TGS[@]}"

  # Derive LoadBalancer ARNs from target groups
  if [[ "$HAS_JQ" == "1" ]]; then
    mapfile -t LBS < <(jq -r '.TargetGroups[].LoadBalancerArns[]?' "$OUTDIR/elbv2/target-groups.json" | sort -u)
  fi

  if [[ "${#LBS[@]}" -gt 0 ]]; then
    echo "== ELBv2 Load Balancers, Listeners, Rules =="
    awsj "$OUTDIR/elbv2/load-balancers.json" elbv2 describe-load-balancers --load-balancer-arns "${LBS[@]}"

    # listeners for each LB
    > "$OUTDIR/elbv2/listeners.json"
    for lb in "${LBS[@]}"; do
      aws --region "$REGION" elbv2 describe-listeners --load-balancer-arn "$lb" \
        | ( [[ "$HAS_JQ" == "1" ]] && jq -S . || cat ) \
        >> "$OUTDIR/elbv2/listeners.json"
      echo "" >> "$OUTDIR/elbv2/listeners.json"
    done

    # rules for each listener
    if [[ "$HAS_JQ" == "1" ]]; then
      mapfile -t LISTENERS < <(jq -r '..|.ListenerArn? // empty' "$OUTDIR/elbv2/listeners.json" | sort -u)
      > "$OUTDIR/elbv2/listener-rules.json"
      for lis in "${LISTENERS[@]}"; do
        aws --region "$REGION" elbv2 describe-rules --listener-arn "$lis" \
          | jq -S . \
          >> "$OUTDIR/elbv2/listener-rules.json"
        echo "" >> "$OUTDIR/elbv2/listener-rules.json"
      done
    fi
  fi
fi

echo "== EC2/VPC objects (subnets, route tables, NAT, IGW, NACLs, SGs) =="
if [[ "${#SUBNETS[@]}" -gt 0 ]]; then
  awsj "$OUTDIR/ec2/subnets.json" ec2 describe-subnets --subnet-ids "${SUBNETS[@]}"

  # VPC IDs from subnets
  if [[ "$HAS_JQ" == "1" ]]; then
    mapfile -t VPCS < <(jq -r '.Subnets[].VpcId' "$OUTDIR/ec2/subnets.json" | sort -u)
  fi

  if [[ "${#VPCS[@]}" -gt 0 ]]; then
    awsj "$OUTDIR/ec2/vpcs.json" ec2 describe-vpcs --vpc-ids "${VPCS[@]}"
    awsj "$OUTDIR/ec2/route-tables.json" ec2 describe-route-tables --filters "Name=vpc-id,Values=$(IFS=,; echo "${VPCS[*]}")"
    awsj "$OUTDIR/ec2/nat-gateways.json" ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$(IFS=,; echo "${VPCS[*]}")"
    awsj "$OUTDIR/ec2/internet-gateways.json" ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$(IFS=,; echo "${VPCS[*]}")"
    awsj "$OUTDIR/ec2/network-acls.json" ec2 describe-network-acls --filters "Name=vpc-id,Values=$(IFS=,; echo "${VPCS[*]}")"
  fi
fi

if [[ "${#SGS[@]}" -gt 0 ]]; then
  awsj "$OUTDIR/ec2/security-groups.json" ec2 describe-security-groups --group-ids "${SGS[@]}"
fi

echo "== IAM Roles referenced by task defs =="
if [[ "$HAS_JQ" == "1" ]]; then
  EXEC_ROLES=$(jq -r '.taskDefinition.executionRoleArn? // empty' "$OUTDIR/ecs/taskdef-frontend.json" "$OUTDIR/ecs/taskdef-backend.json" | sort -u)
  TASK_ROLES=$(jq -r '.taskDefinition.taskRoleArn? // empty' "$OUTDIR/ecs/taskdef-frontend.json" "$OUTDIR/ecs/taskdef-backend.json" | sort -u)

  printf "%s\n" $EXEC_ROLES $TASK_ROLES | sort -u > "$OUTDIR/tmp/role-arns.txt" || true

  while read -r rolearn; do
    [[ -z "$rolearn" ]] && continue
    role="${rolearn##*/}"
    awsj "$OUTDIR/iam/role-${role}.json" iam get-role --role-name "$role" || true
    awsj "$OUTDIR/iam/role-${role}-policies.json" iam list-attached-role-policies --role-name "$role" || true
    awsj "$OUTDIR/iam/role-${role}-inline.json" iam list-role-policies --role-name "$role" || true
  done < "$OUTDIR/tmp/role-arns.txt"
fi

echo "== CloudWatch log groups used by task defs =="
if [[ "$HAS_JQ" == "1" ]]; then
  jq -r '
    .taskDefinition.containerDefinitions[]?
    | select(.logConfiguration.logDriver=="awslogs")
    | .logConfiguration.options."awslogs-group"? // empty
  ' "$OUTDIR/ecs/taskdef-frontend.json" "$OUTDIR/ecs/taskdef-backend.json" | sort -u > "$OUTDIR/tmp/log-groups.txt"

  while read -r lg; do
    [[ -z "$lg" ]] && continue
    awsj "$OUTDIR/logs/log-group-$(echo "$lg" | tr "/:" "__").json" logs describe-log-groups --log-group-name-prefix "$lg" || true
  done < "$OUTDIR/tmp/log-groups.txt"
fi

echo "== Secrets Manager ARNs referenced by task defs (if any) =="
if [[ "$HAS_JQ" == "1" ]]; then
  jq -r '
    .taskDefinition.containerDefinitions[]?.secrets[]?.valueFrom? // empty
  ' "$OUTDIR/ecs/taskdef-frontend.json" "$OUTDIR/ecs/taskdef-backend.json" | sort -u > "$OUTDIR/tmp/secret-arns.txt"

  while read -r sarn; do
    [[ -z "$sarn" ]] && continue
    # describe-secret requires SecretId which can be ARN
    awsj "$OUTDIR/secrets/secret-$(echo "$sarn" | tr "/:" "__").json" secretsmanager describe-secret --secret-id "$sarn" || true
  done < "$OUTDIR/tmp/secret-arns.txt"
fi

echo "== Write a human-readable summary =="
cat > "$OUTDIR/README.md" <<EOF
# AWS Snapshot ($(date +%Y-%m-%d))

Region: $REGION  
Cluster: $CLUSTER_ARN  
Frontend service: $FE_SERVICE  
Backend service: $BE_SERVICE  

## What's captured
- ECS cluster/services/task definitions
- Target groups, load balancers, listeners, rules (if services are attached)
- VPC/subnets/route tables/NAT/IGW/NACLs and referenced Security Groups
- IAM roles referenced by task definitions (role + attached policies)
- CloudWatch log groups referenced by task definitions
- Secrets Manager secret metadata referenced by task definitions (no secret values)

## Files
- ecs/: ECS objects
- elbv2/: ALB/NLB objects
- ec2/: VPC networking objects
- iam/: IAM roles/policies (metadata)
- logs/: log group metadata
- secrets/: secret metadata
EOF

echo "Done. Output: $OUTDIR"
