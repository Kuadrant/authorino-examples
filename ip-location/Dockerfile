FROM mirror.gcr.io/library/ruby:3.1

RUN bundle config --global frozen 1

WORKDIR /usr/src/app

ENV PORT=3000 \
    ENVIRONMENT=production

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

ENTRYPOINT [ "sh", "-c" ]
CMD ["exec rackup -Ilib --port $PORT --env $ENVIRONMENT"]
