# Stage 1: Build release
FROM elixir:1.19.5-otp-28-slim AS builder

RUN apt-get update && apt-get install -y build-essential git && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Cache deps (only mix.exs + config needed for dep resolution)
COPY mix.exs mix.lock ./
COPY apps/zeval_core/mix.exs apps/zeval_core/
COPY apps/zeval_web/mix.exs apps/zeval_web/
COPY config/ config/
RUN mix do deps.get --only prod, deps.compile

# Copy all source
COPY apps/ apps/
COPY priv/ priv/

# Compile and build release
RUN mix compile
RUN mix release zeval_engine

# Stage 2: Runtime
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y libstdc++6 openssl ca-certificates locales && rm -rf /var/lib/apt/lists/* && \
    echo "C.UTF-8" > /etc/locale.gen && locale-gen

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/zeval_engine ./

EXPOSE 4000

ENV LANG=C.UTF-8

# Run migrations then start
CMD ["sh", "-c", "bin/zeval_engine eval \"ZevalCore.Release.migrate()\" && bin/zeval_engine start"]
