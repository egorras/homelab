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

# node:22-bookworm-slim already ships a uid-1000 "node" user/home - reuse it instead of creating
# a second one (useradd would collide on uid 1000).
ENV HOME=/home/node
ENV PATH="/home/node/.multica/bin:${PATH}"

USER node
WORKDIR /home/node

RUN curl -fsSL https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.sh | bash

# --foreground keeps it as PID 1; --no-auto-update/-reload because version changes should come
# from rebuilding this image, not the daemon mutating its own binary on the PVC at runtime.
CMD ["multica", "daemon", "start", "--foreground", "--no-auto-update", "--no-auto-reload", "--runtime-name", "homelab-k3s"]
