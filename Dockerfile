FROM ruby:2.1.9

RUN apt-get update -qq

ADD . /code/Ruby-Docker
WORKDIR /code/Ruby-Docker

# use the bundler version defined in the Gemfile.lock
RUN gem install bundler -v 1.17.3
RUN gem uninstall -i /usr/local/lib/ruby/gems/2.1.0 bundler

RUN bundle install

CMD ["bash"]
