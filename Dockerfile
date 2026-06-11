# Stage 1: Build
FROM hexpm/elixir:1.19.5-erlang-28.0.1-alpine-3.21.3 AS builder

RUN apk add --no-cache build-base git

WORKDIR /app
ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Cache deps
COPY mix.exs mix.lock ./
COPY config/ config/
COPY apps/zeval_core/mix.exs apps/zeval_core/
COPY apps/zeval_web/mix.exs apps/zeval_web/

RUN mix do deps.get --only prod, deps.compile

# Copy source
COPY apps/ apps/

# Compile and build release
RUN mix compile
RUN mix release zeval_engine

# Stage 2: Runtime
FROM alpine:3.21

RUN apk add --no-cache libstdc++ ncurses-libs openssl

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/zeval_engine ./

EXPOSE 4000
CMD ["./bin/zeval_engine", "start"]
