# Terraform using Localstack

This repository illustrates Terraform project for provisioning AWS resources locally with [LocalStack](https://www.localstack.cloud/), and for running Terraform plans and applies through GitHub Actions.

## 1. Repository Structure

```text
.
├── .github/
│   ├── actions/setup-terraform-local/   # Reusable Terraform and LocalStack setup action
│   └── workflows/                       # CI/CD workflows
├── environments/
│   ├── dev/                             # Dev environment configuration
│   ├── stage/                           # Pre-prod environment configuration
│   └── prod/                            # Prod environment configuration
├── modules/
│   ├── s3/                              # Implemented reusable S3 module
│   ├── application/                     
│   ├── dynamodb/                        
│   ├── iam/                             
│   └── networking/                      
├── scripts/                             # Helper scripts
├── tests/                               # Terraform tests
├── docker-compose.yml                                                
```

## 2. Prerequisites

Create a environment for Localstack locally. so that this environment will be our dev environment for running 
and creating AWS(~Locastack) resources using terraform.

```bash
# Ensure docker is running
docker info

# Install lstk (localstack)
npm install -g @localstack/lstk

# Start lstk
lstk start

# Ensure a docker container for localstack is running
docker ps
localstack/localstack-pro:latest
```

Goto https://app.localstack.cloud/getting-started and ensure cluster is up and running.
Here, you can notice you can create allowed(freemuim) resources directly through console.

But, we want to create these resources from Terraform and automate using Github action pipeline.

## 3. LocalStack & Self-Hosted Setup 

We want to setup tools required for localstack to work properly, inside the container where localstack is hosted.
This is because we can point this exact container in Github action pipeline for automatic infra provisioning.

```bash
# Login/exec inside the container where localstack is running
docker exec -it --user root localstack-aws /bin/bash

# ------Tools setup------
# Update packages and install curl, jq, git, unzip
apt-get update && apt-get install -y curl jq git unzip tar sudo ca-certificates

# Install Terraform (v1.11.0)
curl -fsSL https://releases.hashicorp.com/terraform/1.11.0/terraform_1.11.0_linux_amd64.zip -o terraform.zip \
  && unzip terraform.zip -d /usr/local/bin \
  && rm terraform.zip

# Create virtualenv
python3 -m venv .venv
source .venv/bin/activate

# Install tflocal
pip install --no-cache-dir terraform-local
tflocal --version

# ------Runner setup------

# Create and navigate to the runner directory
mkdir -p /actions-runner && cd /actions-runner

# 2. Download the ARM64 runner build
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
curl -o actions-runner-linux-arm64.tar.gz -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz"

# 3. Extract it
tar xzf actions-runner-linux-arm64.tar.gz
rm actions-runner-linux-arm64.tar.gz

# 4. Install dependencies
./bin/installdependencies.sh

curl -fsSL https://releases.hashicorp.com/terraform/1.11.0/terraform_1.11.0_linux_arm64.zip -o terraform.zip \
  && unzip -o terraform.zip -d /usr/local/bin \
  && rm terraform.zip

export RUNNER_ALLOW_RUNASROOT="1"
./config.sh \
  --url https://github.com/ashif8984/terraform-localstack \
  --token <YOUR_TOKEN> \
  --name "localstack-container-runner" \
  --labels "localstack-container,self-hosted" \
  --unattended \
  --replace

<YOUR_TOKEN> - Can be fetched from Github → Settings → Actions → Runners → New self-hosted runner

# Last check
terraform -version
tflocal --version
python3 --version
jq --version

# Runner running in background
nohup ./run.sh > /actions-runner/runner.log 2>&1 &

# Ensure workflow file will have this runner set and not ubuntu-latest
runs-on: self-hosted
```

## 3. Terraform Setup


### [State File] 

The development backend expects an S3 bucket named `s3-state-bucket` to store the terraform state files

You can create the bucket from console or CLI
```bash
awslocal s3 mb s3://s3-state-bucket --region us-east-1
```
The state file will be stored under : environments/<ENV>/terraform.tfstate

### [Terraform Files] 

Each environment should contain its own Terraform root configuration. The active development environment contains:

| File | Purpose |
|---|---|
| `backend.tf` | Stores state in the `s3-state-bucket` backend under the environment-specific key. |
| `main.tf` | Instantiates the reusable modules for this environment. |
| `providers.tf` | Configures the AWS provider and optionally redirects S3 to LocalStack. |
| `variables.tf` | Declares environment inputs and defaults. |
| `terraform.tfvars` | Supplies development values. |

The provider variable `use_localstack` defaults to `true`. With that setting, Terraform uses mock credentials, S3 path-style addressing, and the LocalStack S3 endpoint. To target real AWS, set `use_localstack = false`, provide valid AWS authentication through the normal AWS credential chain, and review the backend and resource names before applying.


### [Terraform Modules]

The reusable module in `modules/` is called with these required inputs:

```hcl
module "example_bucket" {
  source       = "../../modules/s3"
  bucket_name  = "example-bucket"
  environment  = var.environment
  project_name = var.project_name
}
```

Read the guide for using the modules- modules/s3/README.md

## 4. Local Development Workflow

Run all Terraform commands from the environment directory:

```bash
docker exec -it --user root localstack-aws /bin/bash
cd environments/dev

# Initialize the backend
tflocal init 

# Format/Check the files, folders
tflocal fmt -recursive . ../../modules
tflocal fmt -check -recursive . ../../modules

# Validate terraform files
tflocal validate -no-color

# Plan
tflocal plan 

# Apply (Apply the configuration only after reviewing the plan)
tflocal apply 

# To remove all the resources
tflocal destroy
```


## 5. GitHub Actions Workflow

The workflow is located at `.github/workflows/terraform-workflow.yml` and is named `Terraform Dev`.

It runs for pushes that target `main` and for pull requests targeting `main`. 
Changes only to `README.md` are ignored for push events. 
The workflow uses a self-hosted runner and expects the runner to already have Terraform, `tflocal`, Python, and `jq` installed.

### Plan job

The `terraform-plan` job:

1. Checks out the repository.
2. Prints the Terraform, `tflocal`, and Python versions.
3. Runs `tflocal init` and `tflocal test`.
4. Checks Terraform formatting for the environment and modules.
5. Runs `tflocal validate`.
6. Creates `environments/dev/tfplan` with `tflocal plan`.
7. Converts the plan to JSON and prints a resource-change table.
8. Uploads the plan and lock file as the `tfplan` artifact.

### Apply job

The `terraform-apply` job depends on a successful plan. 
It uses the GitHub environment `terraform-dev`, which is the place to configure required reviewers or deployment protection rules. 
After approval, it downloads the plan artifact, initializes Terraform, and applies the saved plan.

Before relying on this job, verify that `tflocal` is on the runner's `PATH`. The current apply job adds `/opt/code/localstack/.venv/bin`, while the setup instructions in `README.md` create `.venv` relative to the working directory. Align these paths on the runner if the command is not found.


### Execution flow

1. Users add a terraform resource. Example - networking_bucket under environment/dev/main.tf

```yaml
module "networking_bucket" {
  source         = "../../modules/s3"
  bucket_name    = "${var.project_name}-${var.environment}-network"
  environment    = var.environment
  enable_logging = var.enable_logging
  project_name   = var.project_name
}
```
2. Validate using tflocal validate and tflocal fmt.
3. Commit and checkin to the remote repository using - git commit, git push
4. Terraform pipelines runs under Github > Actions tab
5. Pipeline first run the terraform-plan job, outputs the plan and upload to artifact
6. Approver reviews the plan and provides/reject the workflow
7. One approved, the terraform-apply job runs, downloads the artifact and apply the changes
8. Once completed successfully, you can navigate to the Localstack cluster web page and ensure reources are created

### [ Optional ] Composite setup action

This action can be used, when you want the github action itself to install all the tools mentioned in step 3. LocalStack Setup on the self-hosted runner.
`.github/actions/setup-terraform-local/action.yml` defines a reusable action that can:

- Install Terraform `1.11.0`
- Install Python `3.10`
- Install `terraform-local`
- Start LocalStack using `LocalStack/setup-localstack`
- Configure LocalStack secret with `LOCALSTACK_AUTH_TOKEN`

The current workflow does not call this composite action; it assumes the self-hosted runner is already prepared. If the action is enabled later, store the LocalStack token as a GitHub Actions secret and pass it through the action input. Never commit the token to the repository.

## 8. Recommended GitHub Configuration

For the workflow to operate reliably:

- Register a self-hosted runner with the labels expected by the workflow. (Check above steps)
- Ensure LocalStack is running and reachable from the runner.
- Install `terraform`, `tflocal`, `python3`, and `jq` on the runner.
- Create the `terraform-dev` GitHub environment.
- Add required reviewers to `terraform-dev` if manual approval is required.
- Keep LocalStack tokens and cloud credentials in GitHub Secrets or the runner environment.
- Confirm that the S3 backend bucket exists before the first workflow run.
- Treat the uploaded `tfplan` artifact as deployment-sensitive data.

