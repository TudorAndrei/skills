---
name: min-size-docker
description: Reduce, audit, or explain Docker and OCI container image size without sacrificing a reliable build or runtime. Use whenever a user reports a bloated image, slow image pulls, Dockerfile layer waste, oversized build context, Python package/image bloat, multi-stage build opportunities, or asks whether to use slim or Alpine. Measure before changing, preserve reproducibility, and explicitly explain size-versus-maintenance tradeoffs.
---

# Min-Size Docker

Optimize images as a measured, workload-specific exercise. A tiny base image is not automatically a smaller or more maintainable application image; compiled dependencies, runtime libraries, build time, and security update workflow all matter.

## Workflow

1. Establish the target: current image/tag, desired outcome (smaller pulls, faster CI, lower registry cost, cold-start limits), platform(s), and whether this is a production runtime image or a development/tooling image. Inspect the Dockerfile, `.dockerignore`, compose/build configuration, and lock files before editing.
2. Record a baseline image size and build time. Inspect the image's layer contributions with `docker history --no-trunc` and use a layer explorer such as `dive` when available. Measure the compressed image size if registry transfer is the concern; local uncompressed size alone can mislead.
3. Reduce the build context first. Add or tighten `.dockerignore` so source-control metadata, editor settings, virtual environments, node modules, test artifacts, notebooks, local data, trained models, credentials, and build outputs are not sent to Docker unless the image genuinely needs them. Prefer an allowlist for unusually large repositories.
4. Select an appropriate base image. Start with the vendor-supported slim/runtime variant that matches the application. For Python, `python:<version>-slim` is generally the sensible default for packages with native extensions because it can use broadly available binary wheels. Pin by supported minor version or digest according to the project's update policy.
5. Structure layers around change frequency and cache value:

   ```Dockerfile
   FROM python:3.12-slim
   WORKDIR /app
   COPY requirements.txt .
   RUN pip install --no-cache-dir -r requirements.txt
   COPY . .
   CMD ["python", "-m", "myapp"]
   ```

   Copy dependency manifests and install dependencies before application code so normal code edits retain the expensive dependency layer. Do not copy more than the runtime needs.

6. Make temporary files disappear in the _same_ `RUN` layer that created them. A later `RUN rm -rf ...` only hides content from the final filesystem; the bytes remain in an earlier image layer. Use package-manager cleanup and `pip --no-cache-dir` in the install command itself. Combine only operations that belong to one disposable transaction—do not merge unrelated steps merely to reduce layer count.
7. Separate build-only tooling from the runtime with a multi-stage build when compilation, asset bundling, or packaging is required. Copy only the application artifact, installed virtual environment, wheels, or compiled output into the final stage. Install only libraries actually needed at runtime in that stage.
8. Treat Alpine/musl as an experiment, not a default. Check whether all dependencies have suitable `musllinux` wheels for the target architecture and Python version. If they do not, source compilation can require a large toolchain, extend builds considerably, and yield a larger or less supportable result than a slim glibc image. Keep Alpine only when its measured total outcome and operational costs are better.
9. For Python native packages, prefer prebuilt, compatible wheels when possible. If source builds are unavoidable, build wheels in a builder stage and install/copy them in the runtime stage. Use `auditwheel`/wheel repair only for a deliberate, tested Linux wheel-distribution workflow; it can bundle shared libraries, complicates licensing and vulnerability updates, and is rarely the first optimization to reach for.
10. Rebuild from a clean cache when validating, run the existing tests or a container smoke test, and compare size, build time, startup, and runtime dependencies with the baseline. Report the before/after result and regressions or maintenance costs.

## Package-manager patterns

Use the ecosystem's cache cleanup in the same transaction as installation. Adapt names and versions to the base image; never paste a package list blindly.

```Dockerfile
# Debian/Ubuntu-family runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends libexample1 \
    && rm -rf /var/lib/apt/lists/*
```

```Dockerfile
# BuildKit cache mounts speed rebuilds without baking the cache into the layer.
# They require an enabled BuildKit-compatible builder.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip wheel --wheel-dir /wheels -r requirements.txt
```

For OS package managers, avoid unpinned `latest` images and separate `apt-get update` from `apt-get install`: stale cache behavior makes builds less reproducible. Prefer package-manager flags that skip documentation or recommended packages only when the runtime does not need them.

## Multi-stage Python template

Use this as a starting point for dependencies that must compile. It deliberately keeps the final image on the same distribution family as the builder, minimizing ABI surprises.

```Dockerfile
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt \
    && rm -rf /var/lib/apt/lists/*

FROM python:3.12-slim AS runtime
WORKDIR /app
# Add only runtime shared libraries that the installed wheels need.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libexample1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /wheels /wheels
COPY requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt \
    && rm -rf /wheels
COPY src/ ./src/
USER 10001
CMD ["python", "-m", "src"]
```

Replace the placeholder runtime library based on actual inspection and tests. Do not copy an entire builder filesystem into the runtime image.

## Common traps

- Deleting files in a later layer does not reclaim bytes from the image. Create and remove temporary files in one layer, or keep them in a builder stage.
- `docker build --squash` (where supported) can conceal poor layering and reduces cache reuse. Fix the Dockerfile before considering it.
- Removing `.py`, `.pyi`, tests, licenses, docs, or shared libraries from `site-packages` is fragile. Only remove a class of files after tests and license/compliance requirements confirm it is safe; do not strip code needed for tracebacks, plugins, type-driven runtime behavior, or package metadata.
- `COPY . .` is safe only when `.dockerignore` is deliberately maintained. Prefer targeted `COPY` statements for high-assurance images.
- Static linking, wheel repair, compiler flags, symlink deduplication, and binary stripping are advanced tactics. Use them only after the simple improvements are measured and when they do not compromise debugging, compatibility, licensing, or future security updates.
- Never put secrets in a build context, image layer, `ARG`, or `ENV`. Use the build system's secret mounts/credentials instead.

## Report format

Conclude image-size work with:

```text
Baseline: <image/tag>, <size>, <build duration>
Changes: <short list>
Result: <size> (<absolute and percent delta>), <build duration delta>
Validation: <tests/smoke command and result>
Tradeoffs / follow-up: <runtime libraries, cache behavior, base-image update policy, or remaining largest layer>
```
