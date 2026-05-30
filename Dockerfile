# Build the static MkDocs site with the pinned mkdocs-material, then serve it
# with nginx. The `FROM squidfunk/mkdocs-material:<ver>` line is what the
# ci-templates docker-build workflow greps to derive the image tag suffix
# (e.g. -mkdocs9.5.49). Keep this version in sync with requirements.txt.
FROM squidfunk/mkdocs-material:9.5.49 AS builder
WORKDIR /docs
COPY . .
RUN mkdocs build

FROM nginx:1.27-alpine
COPY --from=builder /docs/site /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
