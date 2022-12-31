ARG BUILDER_IMAGE="hexpm/elixir:1.14.2-erlang-25.0.4-debian-bullseye-20220801-slim"
ARG RUNNER_IMAGE="debian:bullseye-20220801-slim"

FROM ${BUILDER_IMAGE} AS builder

# Set env variables
ENV MIX_ENV="prod"

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install Hex and rebar3
RUN mix do local.hex --force, local.rebar --force


# Install Mix dependencies
COPY mix.exs ./
RUN mix do deps.get --only $MIX_ENV, deps.compile

# Compile the release
COPY lib lib
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY rel rel
RUN mix release

## Runner image

FROM ${RUNNER_IMAGE}

# Install dependencies
RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app

COPY --from=builder /app/_build/prod/rel ./

CMD /app/protohackers/bin/protohackers start
