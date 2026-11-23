# service-images/mcp-actual/Dockerfile
FROM node:24-alpine
ARG ACTUAL_MCP_VERSION=1.15.1
RUN npm install -g actual-mcp@${ACTUAL_MCP_VERSION}
EXPOSE 3310
ENTRYPOINT ["actual-mcp"]
