FROM ruby:2.3
RUN apt-get update \
    && apt-get install -y --no-install-recommends smbclient \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile* ./
COPY *gemspec ./
COPY lib/smbclient/version.rb ./lib/smbclient/
RUN bundle install

COPY . ./

CMD ["ruby", "test/smbclient/smb_test.rb"]