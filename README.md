
# RightCloudApi shared library

This is a Ruby gem that provides common code to all RightScale cloud libraries. It is required by the respective cloud library gems. See https://github.com/rightscale/right_aws_api for example.

### Tests

```
  bundle install
  bundle exec rake spec

```

### (c) 2014 by RightScale, Inc., see the LICENSE file for the open-source license.

## Using Docker
To run the tests locally, install Docker and Docker-compose and run `docker-compose up`, it will take care of building the docker image and running the rspec specs.
