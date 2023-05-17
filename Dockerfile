# https://github.com/cloudposse/geodesic/
ARG GEODESIC_VERSION=2.1.2
ARG GEODESIC_OS=debian
# https://github.com/cloudposse/atmos
ARG ATMOS_VERSION=1.35.0
# This should match the version set in stacks/catalog/spacelift.yaml
# This should match the version set in .github/workflows/auto-format.yaml
ARG TF_1_VERSION=1.3.9
ARG INFRACOST_VERSION='0.10.*'

FROM cloudposse/geodesic:${GEODESIC_VERSION}-${GEODESIC_OS}

# Geodesic message of the Day
ENV MOTD_URL="https://geodesic.sh/motd"

# Some configuration options for Geodesic
ENV AWS_SAML2AWS_ENABLED=false
ENV AWS_VAULT_ENABLED=false
ENV AWS_VAULT_SERVER_ENABLED=false
ENV CHAMBER_KMS_KEY_ALIAS=aws/ssm
ENV GEODESIC_TF_PROMPT_ACTIVE=false
ENV DIRENV_ENABLED=false

# Enable advanced AWS assume role chaining for tools using AWS SDK
# https://docs.aws.amazon.com/sdk-for-go/api/aws/session/
ENV AWS_SDK_LOAD_CONFIG=1
ENV AWS_DEFAULT_REGION=us-east-1
ENV AWS_DEFAULT_SHORT_REGION=ue1
ENV AWS_REGION_ABBREVIATION_TYPE=fixed

# Install specific versions of Terraform. Must match versions in Spacelift terraform_version_map
# in components/terraform/spacelift/default.auto.tfvars
ARG TF_1_VERSION
RUN apt-get update && apt-get install -y -u --allow-downgrades \
    terraform-1="${TF_1_VERSION}-*" && \
    update-alternatives --set terraform /usr/share/terraform/1/bin/terraform

# https://github.com/Versent/saml2aws#linux
ARG ATMOS_VERSION
ARG INFRACOST_VERSION
RUN apt-get update && apt-get install -y --allow-downgrades \
    atmos="${ATMOS_VERSION}-*" \
    infracost="${INFRACOST_VERSION}" \
    rainbow-text \
    spacectl \
    spotctl

COPY rootfs/ /


ARG DOCKER_REPO
ARG TENANT="core"
ENV NAMESPACE="mcal"
# Format of Geodesic banner prompt
ENV BANNER='${NAMESPACE}${TENANT:+ ($TENANT)}'
# Command to display banner at start of Geodesic session
ENV BANNER_COMMAND="mcalhoun"
ENV DOCKER_IMAGE="${DOCKER_REPO}/${NAMESPACE}"
ENV DOCKER_TAG="latest"

# Default AWS_PROFILE
ENV AWS_PROFILE=${NAMESPACE}${TENANT:+-$TENANT}-gbl-identity
ENV AWS_CONFIG_FILE=/etc/aws-config/aws-config-local
ENV ASSUME_ROLE_INTERACTIVE_QUERY=${NAMESPACE}${TENANT:+-$TENANT}-gbl-

WORKDIR /
