# Multica agent runtime: the daemon that polls for tasks and drives agent CLIs on a real machine.
# Lives in the homelab k3s cluster so it's always on (docs/runbooks/multica.md), unlike the user's
# PC. Image only; config/auth/workspaces all live on the PVC mounted at $HOME so the one-time
# interactive logins (claude/codex/multica) survive pod restarts.
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      git openssh-client ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Agent CLIs multica drives. Pin versions deliberately (never @latest) so an image rebuild is the
# only thing that changes what's running - matches this repo's "pinned tag" convention.
RUN npm install -g @anthropic-ai/claude-code@2.1.291 @openai/codex@0.160.1

# Install as root, while /usr/local/bin is still writable, so the binary lands there - not under
# $HOME. The installer (scripts/install.sh) falls back to $HOME/.local/bin otherwise, which the
# PVC mounted over /home/node at runtime would hide completely (Codex review on PR #44).
RUN curl -fsSL https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.sh | bash

# node:22-bookworm-slim already ships a uid-1000 "node" user/home - reuse it instead of creating
# a second one (useradd would collide on uid 1000).
ENV HOME=/home/node
USER node
WORKDIR /home/node

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
CMD ["/usr/local/bin/entrypoint.sh"]
