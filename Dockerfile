FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=8080

COPY package*.json ./
RUN npm ci

COPY src ./src

USER node
EXPOSE 8080
CMD ["npm", "start"]
