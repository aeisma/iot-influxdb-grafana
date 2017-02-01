#!/bin/bash -e

: "${GF_PATHS_VOLUME:=/var/lib/grafana}"
: "${GF_PATHS_DATA:=/var/lib/grafana/data}"
: "${GF_PATHS_LOGS:=/var/log/grafana}"
: "${GF_PATHS_PLUGINS:=/var/lib/grafana/plugins}"

# In IBM Containers, the user namespace is enabled for docker engine.
# When the user namespace is enabled, the effective root inside the
# container is a non-root user out side the container process and NFS
# is not allowing the mapped non-root user to perform the chown operation
# on the volume inside the container.

# This requires some changes to the run script for the Grafana image
# from https://github.com/grafana/grafana-docker

#chown -R grafana:grafana "$GF_PATHS_DATA" "$GF_PATHS_LOGS"
adduser grafana root
chmod 775 $GF_PATHS_VOLUME
su -s /bin/bash -c "mkdir -p $GF_PATHS_DATA $GF_PATHS_PLUGINS" grafana
chmod 755 $GF_PATHS_VOLUME
deluser grafana root
chown -R grafana:grafana "$GF_PATHS_LOGS"
# End of changes for user namespace

chown -R grafana:grafana /etc/grafana

if [ ! -z ${GF_AWS_PROFILES+x} ]; then
    mkdir -p ~grafana/.aws/
    touch ~grafana/.aws/credentials

    for profile in ${GF_AWS_PROFILES}; do
        access_key_varname="GF_AWS_${profile}_ACCESS_KEY_ID"
        secret_key_varname="GF_AWS_${profile}_SECRET_ACCESS_KEY"
        region_varname="GF_AWS_${profile}_REGION"

        if [ ! -z "${!access_key_varname}" -a ! -z "${!secret_key_varname}" ]; then
            echo "[${profile}]" >> ~grafana/.aws/credentials
            echo "aws_access_key_id = ${!access_key_varname}" >> ~grafana/.aws/credentials
            echo "aws_secret_access_key = ${!secret_key_varname}" >> ~grafana/.aws/credentials
            if [ ! -z "${!region_varname}" ]; then
                echo "region = ${!region_varname}" >> ~grafana/.aws/credentials
            fi
        fi
    done

    chown grafana:grafana -R ~grafana/.aws
    chmod 600 ~grafana/.aws/credentials
fi

if [ ! -z "${GF_INSTALL_PLUGINS}" ]; then
  OLDIFS=$IFS
  IFS=','
  for plugin in ${GF_INSTALL_PLUGINS}; do
    grafana-cli  --pluginsDir "${GF_PATHS_PLUGINS}" plugins install ${plugin}
  done
  IFS=$OLDIFS
fi

exec gosu grafana /usr/sbin/grafana-server      \
  --homepath=/usr/share/grafana                 \
  --config=/etc/grafana/grafana.ini             \
  cfg:default.paths.data="$GF_PATHS_DATA"       \
  cfg:default.paths.logs="$GF_PATHS_LOGS"       \
  cfg:default.paths.plugins="$GF_PATHS_PLUGINS" \
  "$@"
