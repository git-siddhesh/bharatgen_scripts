FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y curl unzip

# Download and extract AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin

# --- Stage 2: The Final Image ---
FROM debian:bookworm-slim

# Install only essentials
RUN apt-get update && apt-get install -y \
    bash \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy AWS CLI from builder
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /usr/local/bin /usr/local/bin

WORKDIR /app

# Copy script
COPY run.sh /mnt/run.sh
RUN chmod +x /mnt/run.sh

# Create logs & results directories
RUN mkdir -p /app/logs /app/results && chmod -R 755 /app

ENTRYPOINT ["/mnt/run.sh"]
