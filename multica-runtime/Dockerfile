# Multica agent runtime: the daemon that polls for tasks and drives agent CLIs on a real machine.
# Lives in the homelab k3s cluster so it's always on (docs/runbooks/multica.md), unlike the user's
# PC. Image only; config/auth/workspaces all live on the PVC mounted at $HOME so the one-time
# interactive logins (claude/codex/multica) survive pod restarts.
FROM node:24-bookworm-slim

# procps: codex's background "app-server" process tracking shells out to `ps`, which this slim
# base image doesn't ship - without it, any codex invocation (not just login) fails immediately.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git openssh-client ca-certificates curl procps \
    && rm -rf /var/lib/apt/lists/*

# Agent CLIs multica drives. Pin versions deliberately (never @latest) so an image rebuild is the
# only thing that changes what's running - matches this repo's "pinned tag" convention.
RUN npm install -g @anthropic-ai/claude-code@2.1.296 @openai/codex@0.162.1

# Pinned like the CLIs above - upstream's own installer always grabs GitHub's "latest" release
# at install time, which would silently drift the binary on every unrelated image rebuild. Fetch
# the release tarball directly instead so Renovate (github-releases datasource) bumps this
# deliberately, matching the npm-pinned CLIs.
ARG MULTICA_VERSION=0.6.3
# Install as root, while /usr/local/bin is still writable, so the binary lands there - not under
# $HOME. The installer (scripts/install.sh) falls back to $HOME/.local/bin otherwise, which the
# PVC mounted over /home/node at runtime would hide completely (Codex review on PR #44).
RUN curl -fsSL "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/multica-cli-${MULTICA_VERSION}-linux-amd64.tar.gz" \
      | tar -xz -C /usr/local/bin multica

# node:22-bookworm-slim already ships a uid-1000 "node" user/home - reuse it instead of creating
# a second one (useradd would collide on uid 1000).
ENV HOME=/home/node
USER node
WORKDIR /home/node

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
CMD ["/usr/local/bin/entrypoint.sh"]
