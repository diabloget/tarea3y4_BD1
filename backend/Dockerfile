FROM ruby:3.3-slim
RUN apt-get update && apt-get install -y freetds-dev freetds-bin build-essential \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile ./
RUN bundle install
COPY . .
EXPOSE 3000
CMD ["ruby", "app.rb"]