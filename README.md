## CodeCommit cross-region mirror (us-east-2 → us-east-1)

- **Source repo**: `dop-c02-repo` (default provider region `us-east-2`)
- **Replica repo**: `dop-c02-repo-replica` (provider alias `aws.use1` in `us-east-1`)
- **Trigger**: CodeCommit `createReference` + `updateReference`
- **Sync mechanism**: Lambda container runs `git clone --mirror` then `git push --mirror`

### Deploy (important: Lambda image must exist)

Terraform creates the ECR repo and the Lambda that references the image tag `latest`. The first `terraform apply` will fail until you push an image to ECR. The usual flow is:

1. Create ECR (and any other infra you want first), for example:

```bash
make init
terraform -chdir=terraform apply -target=aws_ecr_repository.codecommit_mirror
```

2. Build and push the Lambda image:

```bash
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
AWS_REGION="us-east-2"
ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/dop-c02-codecommit-mirror"

aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker build --platform linux/amd64 -t dop-c02-codecommit-mirror ./lambda/codecommit_mirror
docker tag dop-c02-codecommit-mirror:latest "${ECR_REPO}:latest"
docker push "${ECR_REPO}:latest"
```

3. Apply everything:

```bash
make apply
```

### Verify replication

From a local clone of the **source** repo, create a branch/tag and push:

```bash
git checkout -b test-replication
git commit --allow-empty -m "replication test"
git push origin test-replication
git tag test-tag-1
git push origin test-tag-1
```

Then confirm the same branch/tag exists in the **us-east-1** replica repository.

