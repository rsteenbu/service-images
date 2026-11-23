# service-images/mcp-actual/Dockerfile
FROM node:24-alpine
ARG ACTUAL_MCP_VERSION=1.15.1
RUN npm install -g actual-mcp@${ACTUAL_MCP_VERSION}
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
EXPOSE 3310
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
