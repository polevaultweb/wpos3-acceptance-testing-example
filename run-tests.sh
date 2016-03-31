#!/usr/bin/env bash

function usage() {
	echo "Usage: $0 -u dbuser -p dbpassword [ -h dbhost ] [ -s start from scratch ] [ -t path to specific test ]"
	exit 2
}

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/4;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);

      }
   }'
}

while getopts "u:p:h:st" ARG
do
	case ${ARG} in
	    u)  DB_USER=$OPTARG;;
	    p)  DB_PASS=$OPTARG;;
	    h)  DB_HOST=$OPTARG;;
		s)	START_FROM_SCRATCH=true;;
		t)  TEST_PATH=$OPTARG;;
		\?)	usage;;
	esac
done
shift `expr $OPTIND - 1`

if [ ! -f ./codeception.yml ]; then
    echo 'codeception.yml missing'
    exit;
fi

eval $(parse_yaml ./codeception.yml)

if [ -z $modules_config_S3Filesystem_accessKey ]; then
    echo 'AWS_ACCESS_KEY_ID config value required in codeception.yml'
    exit;
else
AWS_ACCESS_KEY_ID=$modules_config_S3Filesystem_accessKey
fi

if [ -z $modules_config_S3Filesystem_accessSecret ]; then
    echo 'AWS_SECRET_ACCESS_KEY config value required in codeception.yml'
    exit;
else
AWS_SECRET_ACCESS_KEY=$modules_config_S3Filesystem_accessSecret
fi

if [ -z $modules_config_S3Filesystem_bucket ]; then
    echo 'AWS_BUCKET config value required in codeception.yml'
    exit;
else
AWS_BUCKET=$modules_config_S3Filesystem_bucket
fi

DB_HOST=${DB_HOST-localhost}
DB_USER=${DB_USER-$modules_config_WPDb_user}
DB_PASS=${DB_PASS-$modules_config_WPDb_password}
START_FROM_SCRATCH=${START_FROM_SCRATCH-false}
USE_PHANTOMJS=${USE_PHANTOMJS-false}
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DB_NAME=$modules_config_WPDb_dsn
DB_NAME=${DB_NAME#*dbname=}
WP_SITE_URL=$modules_config_WPBrowser_url
SERVER_PATH="$PROJECT_ROOT/tests/tmp"
WP_SITE_PATH="$SERVER_PATH/wp"

SELENIUM_URL="http://selenium-release.storage.googleapis.com/2.49/selenium-server-standalone-2.49.1.jar"
SELENIUM_FILENAME="${SELENIUM_URL##*/}"

mkdir -p $SERVER_PATH

if [ ! -f "$SERVER_PATH/$SELENIUM_FILENAME" ]; then
    echo "Downloading Selenium..."
    cd "$SERVER_PATH"
    curl -O "$SELENIUM_URL"
fi

function install_wp() {
    echo "Creating WordPress test site..."
    rm -rf $WP_SITE_PATH
    mkdir $WP_SITE_PATH
    cd "$WP_SITE_PATH"
    cat > .gitignore << EOF
# Ignore all WP
/*
EOF

    wp core download --force
    wp core config --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" --extra-php <<PHP
    define( 'WP_DEBUG', true );
    define( 'WP_DEBUG_DISPLAY', false );
    define( 'WP_DEBUG_LOG', true );
    define( 'AWS_ACCESS_KEY_ID', '$AWS_ACCESS_KEY_ID' );
    define( 'AWS_SECRET_ACCESS_KEY', '$AWS_SECRET_ACCESS_KEY' );
    define( 'WPOS3_SETTINGS', serialize( array(
	                                     'bucket'        => '$AWS_BUCKET',
	                                     'copy-to-s3'    => true,
	                                     'serve-from-s3' => true,
                                     ) ) );
PHP
    echo "Creating WordPress test database..."
    wp db drop --yes
    wp db create
    wp core install --url="$WP_SITE_URL" --title="Acceptance Testing Site" --admin_user="admin" --admin_password="admin" --admin_email="admin@example.com"

    # Install AWS plugins
    wp plugin install amazon-web-services --activate --force
    wp plugin install amazon-s3-and-cloudfront --activate --force
}

if [ 'true' == ${START_FROM_SCRATCH} ] || [ ! -f "$WP_SITE_PATH/index.php" ]; then
    install_wp

    cd $PROJECT_ROOT

    echo "Building Acceptance Tests with Codeception..."
    php ./vendor/bin/codecept build
else
    echo "Resetting WordPress Database..."
    wp post delete $(wp post list --post_type='attachment' --format=ids --path=tests/tmp/wp/) --path=tests/tmp/wp/
fi

cd $PROJECT_ROOT

echo "Running Selenium..."
pkill -f "java -jar $SERVER_PATH/$SELENIUM_FILENAME"
find . -name 'selenium.log*' -delete
java -jar "$SERVER_PATH/$SELENIUM_FILENAME" -log "$SERVER_PATH/selenium.log" &
sleep 1
while ! grep -m1 'Selenium Server is up and running' < "$SERVER_PATH/selenium.log"; do
    sleep 1
done

echo "Running Acceptance Tests with Codeception..."
WP_SITE_PATH="$WP_SITE_PATH" \
php ./vendor/bin/codecept run acceptance

echo "Shutting down Selenium..."
pkill -f "java -jar $SERVER_PATH/$SELENIUM_FILENAME"

echo "Killing Firefox"
pkill -9 firefox
