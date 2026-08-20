


## Self-hosted runner

```bash
docker exec -it --user root localstack-aws /bin/bash


# Update packages and install curl, jq, git, unzip
apt-get update && apt-get install -y curl jq git unzip tar sudo ca-certificates

# Install Terraform (v1.11.0)
curl -fsSL https://releases.hashicorp.com/terraform/1.11.0/terraform_1.11.0_linux_amd64.zip -o terraform.zip \
  && unzip terraform.zip -d /usr/local/bin \
  && rm terraform.zip

# Install tflocal
python3 -m venv .venv
source .venv/bin/activate
pip install --no-cache-dir terraform-local
tflocal --version

pip install --no-cache-dir terraform-local

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

# to keep runner running in background
nohup ./run.sh > /actions-runner/runner.log 2>&1 &

# Update workflow
runs-on: [self-hosted, localstack-container]
```