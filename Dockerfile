# In IBM Containers, the user namespace is enabled for docker engine.
# When the user namespace is enabled, the effective root inside the
# container is a non-root user out side the container process and NFS
# is not allowing the mapped non-root user to perform the chown operation
# on the volume inside the container.

# This requires some changes to the run script for the Grafana image
# from https://github.com/grafana/grafana-docker

FROM grafana/grafana

# Replace the run.sh from grafana/grafana with a version modified
COPY ./run.sh /run.sh
