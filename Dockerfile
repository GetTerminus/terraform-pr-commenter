ARG TERRAFORM_VERSION=1.4.6
FROM hashicorp/terraform:${TERRAFORM_VERSION}

LABEL repository="https://github.com/GetTerminus/terraform-pr-commenter" \
      homepage="https://github.com/GetTerminus/terraform-pr-commenter" \
      maintainer="Terminus Software" \
      com.github.actions.name="Terraform PR Commenter" \
      com.github.actions.description="Adds comments to a PR from Terraform fmt/init/plan/tflint output." \
      com.github.actions.icon="git-pull-request" \
      com.github.actions.color="blue"

RUN apk add --no-cache -q \
    bash \
    add --upgrade curl \
    perl \
    jq \

ADD entrypoint.sh /entrypoint.sh
ADD /handlers /handlers
ADD /utilities /utilities
RUN chmod +x /entrypoint.sh
RUN chmod +x /handlers
RUN chmod +x /utilities

ENTRYPOINT ["/entrypoint.sh"]
