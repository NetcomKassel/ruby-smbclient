FROM ruby:2.3
RUN apt-get update \
    && apt-get install -y --no-install-recommends smbclient \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . ./

RUN bundle install

CMD ["ruby", "test/smbclient/smb_test.rb"]