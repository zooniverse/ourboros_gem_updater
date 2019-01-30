FROM ruby:2.5

WORKDIR /app

ADD ./Gemfile /app/
ADD ./Gemfile.lock /app/

RUN bundle config --global jobs `cat /proc/cpuinfo | grep processor | wc -l | xargs -I % expr % - 1`
RUN bundle install

ADD ./ /app
