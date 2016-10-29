FROM debian:jessie

ENV HEALTHCHECKS_USER="1000" HEALTHCHECKS_GROUP="1000"

RUN groupadd -g "$HEALTHCHECKS_GROUP" healthchecks && \
    useradd -u "$HEALTHCHECKS_USER" -g "$HEALTHCHECKS_GROUP" -m -d /home/healthchecks -s /bin/bash healthchecks

RUN apt-get update && \
    apt-get install -y wget && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" > /etc/apt/sources.list.d/psql.list && \
    wget -q -O- https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
    apt-key add - && \
    apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y git && \
    apt-get install -y python-virtualenv python3 python3-virtualenv python3-dev postgresql-server-dev-9.4 build-essential && \
    mkdir -p /healthchecks && \
    chown healthchecks:healthchecks -R /healthchecks

USER healthchecks

RUN git clone https://github.com/healthchecks/healthchecks.git /healthchecks && \
    cd /healthchecks && \
    virtualenv --python=python3 hc-venv && \
    source hc-venv/bin/activate && \
    pip install -r requirements.txt && \
    easy_install six

USER root

RUN apt-get --purge remove -y build-essential python3-dev

ENTRYPOINT ["docker-entrypoint.sh"]
