## Automated Acceptance Testing Example Using Codeception

This is an example of how to perform automated acceptance testing of a WordPress plugin using [Codeception](http://codeception.com/).

It is a companion to the Delicious Brains [post](https://deliciousbrains.com/?p=15941) on the same topic.

### Requirements

1. [Composer](https://getcomposer.org/)
2. [Java (JDK)](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
3. PHP 5.5+
4. [AWS account](https://aws.amazon.com/)

### Install

1. Clone the repository and `cd` into it.
1. Make sure the permissions are correct on the `tests/tmp` directory using `chmod -R 755 tests/tmp`
1. Run `composer install`
1. Copy the `codeception.dist.yml` file to `codeception.yml`
1. Enter your AWS key, secret and bucket name in the `S3Filesystem` module config in `codeception.yml`
1. Configure your local database credentials in the `WPDb` module config in `codeception.yml`
1. Add a virtual host for `wpos3-acceptance.test` pointing to `/tests/tmp/wp` in the cloned repo

### Running the Tests

`sh run-tests.sh`

Optionally pass `-s` to start from scratch, which removes the WordPress site and re-installs. You don't need this flag the first time.