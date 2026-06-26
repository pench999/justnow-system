FROM ruby:3.3.11-slim

ENV APP_HOME=/app \
    BUNDLE_PATH=/bundle \
    RACK_ENV=production

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      pkg-config \
      ca-certificates \
      curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR $APP_HOME

COPY Gemfile .ruby-version ./
COPY vendor/stratum ./vendor/stratum
RUN bundle install --without development test

COPY . .
RUN chmod +x docker/entrypoint.sh

EXPOSE 9292
ENTRYPOINT ["docker/entrypoint.sh"]
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "--port", "9292", "config.ru"]
