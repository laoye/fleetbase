# ---- Build Stage ----
FROM node:18.15.0-alpine as builder

# Set the working directory in the container to /app
WORKDIR /app

# Create the pnpm directory and set the PNPM_HOME environment variable
RUN mkdir -p ~/.pnpm
ENV PNPM_HOME=/root/.pnpm

# Set environment
ARG ENVIRONMENT=production

# Add the pnpm global bin to the PATH
ENV PATH=/root/.pnpm/bin:$PATH

# Install global dependencies
# pnpm 钉死到 9.5.0（与 console/package.json 的 packageManager 字段一致；pnpm 10 改了 hoisting，找不到 ember-cli/bin/ember）
RUN npm install -g ember-cli pnpm@9.5.0

# Install git
RUN apk update && apk add git openssh-client

# Trust GitHub's RSA host key
RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts

# Copy workspace config first
COPY pnpm-workspace.yaml ./

# Copy local packages
COPY packages/ ./packages/

# Copy console package files for dependency install
COPY console/package.json console/pnpm-lock.yaml ./console/

# Copy over .npmrc if applicable
COPY console/.npmr[c] ./console/

# Install app dependencies (workspace-aware)
WORKDIR /app/console
RUN pnpm install

# Copy the console directory contents
COPY console/ .

# Build the application
RUN pnpm build --environment $ENVIRONMENT

# ---- Serve Stage ----
FROM nginx:alpine

# Copy the built app to our served directory
COPY --from=builder /app/console/dist /usr/share/nginx/html

# Expose the port nginx is bound to
EXPOSE 4200

# Use custom nginx.conf
COPY console/nginx.conf /etc/nginx/conf.d/default.conf

# Start Nginx server
CMD ["nginx", "-g", "daemon off;"]
