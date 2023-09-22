ARG RUBY_VERSION=3.1
ARG OS_VERISON=bullseye
FROM ruby:${RUBY_VERSION}-${OS_VERISON}

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -q -yy --no-install-recommends netbase wkhtmltopdf \
 && rm -rf /var/lib/apt/lists/*

ARG USER_NAME=app
ARG USER_ID=1000
ARG APP_DIR=/app

RUN adduser --uid ${USER_ID} --home ${APP_DIR} --gid 0 ${USER_NAME}

WORKDIR ${APP_DIR}
USER ${USER_NAME}

COPY Gemfile Gemfile
COPY config.ru config.ru
COPY lib lib

RUN bundle install

CMD [ "puma", "-p", "9292" ]