#!/bin/bash

DB_TYPE="${DB_TYPE:-sqlite}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-healthchecks}"
DB_USER="${DB_USER:-healthchecks}"
DB_PASSWORD="${DB_PASSWORD:-healthchecks}"
# Possible settings
# HC_SITE_ROOT=""
# HC_SITE_NAME=""

if [ "$HEALTHCHECKS_USER" != "3000" ]; then
    usermod -u "$HEALTHCHECKS_USER" healthchecks
fi
if [ "$HEALTHCHECKS_GROUP" != "3000" ]; then
    groupmod -g "$HEALTHCHECKS_GROUP" healthchecks
fi

databaseConfiguration() {
    # TODO Wait for database and create database if not exists
    #psql --user postgres <<EOF
#create database hc;
#EOF

    touch /healthchecks/hc/local_settings.py
    if [ "$DB_TYPE" != "sqlite" ]; then
        cat <<EOF > /healthchecks/hc/local_settings.py
DATABASES = {
    'default': {
        'ENGINE':   'django.db.backends.$DB_TYPE',
        'HOST':     '$DB_HOST',
        'PORT':     '$DB_PORT',
        'NAME':     '$DB_NAME',
        'USER':     '$DB_USER',
        'PASSWORD': '$DB_PASSWORD',
        'TEST': {'CHARSET': 'UTF8'}
    }
}
EOF
    fi
}

settingsConfiguration() {
    given_settings=($(env | sed -n -r "s/HC_([0-9A-Za-z_]*).*/\1/p"))
    for setting_key in "${given_settings[@]}"; do
        key="HC_$setting_key"
        setting_var="${!key}"
        if [ -z "$setting_var" ]; then
            echo "Empty var for key \"$setting_key\"."
            continue
        fi
        echo "Added \"$setting_key\" (value \"$setting_var\") to settings.py"
        echo "$setting_key = \"$setting_var\"" >> /healthchecks/hc/local_settings.py
    done
}

appRun() {
    databaseConfiguration
    settingsConfiguration

    echo "Correcting config file permissions ..."
    chmod 755 -f /healthchecks/hc/settings.py /healthchecks/hc/local_settings.py

    cd /healthchecks || exit 1
    echo "Migrating database ..."
    su healthchecks -c 'source /healthchecks/hc-venv/bin/activate; ./manage.py migrate --noinput'

    exec su healthchecks -c 'source /healthchecks/hc-venv/bin/activate; ./manage.py runserver'
}

appManagePy() {
    COMMAND="$1"
    shift 1
    if [ -z "$COMMAND" ]; then
        echo "No command given for manage.py. Defaulting to \"shell\"."
        COMMAND="shell"
    fi
    echo "Running manage.py ..."
    set +e
    exec su healthchecks -c "source /healthchecks/hc-venv/bin/activate; /home/zulip/deployments/current/manage.py $COMMAND $@"
}

appHelp() {
    echo "Available commands:"
    echo "> app:help     - Show this help menu and exit"
    echo "> app:managepy - Run Healthchecks's manage.py script (defaults to \"shell\")"
    echo "> app:run      - Run the Zulip server"
    echo "> [COMMAND]    - Run given command with arguments in shell"
}

case "$1" in
    app:run)
        appRun
    ;;
    app:managepy)
        shift 1
        appManagePy "$@"
    ;;
    app:help)
        appHelp
    ;;
    app:version)
        appVersion
    ;;
    *)
        if [[ -x $1 ]]; then
            $1
        else
            COMMAND="$1"
            if [[ -n $(which $COMMAND) ]] ; then
                echo "=> Running command: $(which $COMMAND) $@"
                shift 1
                exec "$(which $COMMAND)" "$@"
            else
                appHelp
            fi
        fi
    ;;
esac
