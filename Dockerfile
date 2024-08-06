ARG TOFU_VERSION=1.8.0
FROM ghcr.io/opentofu/opentofu:${TOFU_VERSION}

LABEL repository="https://github.com/phoenix-actions/opentofu-pr-commenter" \
      homepage="https://github.com/phoenix-actions/opentofu-pr-commenter" \
      maintainer="Phoenix Actions" \
      com.github.actions.name="OpenTofu PR Commenter" \
      com.github.actions.description="Adds comments to a PR from OpenTofu fmt/init/plan/tflint output." \
      com.github.actions.icon="git-pull-request" \
      com.github.actions.color="blue"

RUN apk add --no-cache -q \
    bash \
    curl \
    perl \
    jq \
    && apk add --upgrade curl

ADD entrypoint.sh /entrypoint.sh
ADD /handlers /handlers
ADD /utilities /utilities
RUN chmod +x /entrypoint.sh
RUN chmod +x /handlers
RUN chmod +x /utilities

ENTRYPOINT ["/entrypoint.sh"]
