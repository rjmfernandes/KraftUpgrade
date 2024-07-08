FROM ubuntu:20.04
LABEL maintainer="Jeff Geerling, Rui Fernandes"

ARG DEBIAN_FRONTEND=noninteractive

ENV pip_packages "ansible"

COPY initctl_faker .

# Install dependencies and set up whole system (squashed into one large script in order to avoid creating many image layers)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       apt-utils \
       build-essential \
       locales \
       libffi-dev \
       libssl-dev \
       libyaml-dev \
       python3-dev \
       python3-setuptools \
       python3-pip \
       python3-yaml \
       software-properties-common \
       rsyslog systemd systemd-cron sudo iproute2 \
       openjdk-17-jdk \
       apt-transport-https \
       git \
       inetutils-ping \
       bind9-host \
       docker.io \
       vim \
    && apt-get clean \
    && rm -Rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && sed -i 's/^\($ModLoad imklog\)/#\1/' /etc/rsyslog.conf \
    # Fix potential UTF-8 errors with ansible-test.
    && locale-gen en_US.UTF-8 \
    # Install Ansible via Pip.
    && pip3 install $pip_packages \
    && chmod +x initctl_faker \
    && rm -fr /sbin/initctl \
    && ln -s /initctl_faker /sbin/initctl \
    # Install Ansible inventory file.
    && mkdir -p /etc/ansible \
    && echo "[local]\nlocalhost ansible_connection=local" > /etc/ansible/hosts \
    && printf "[defaults]\nhash_behaviour=merge\n" > /etc/ansible/ansible.cfg \
    && ansible-galaxy collection install git+https://github.com/confluentinc/cp-ansible.git,7.6.0 \
    # Remove unnecessary getty and udev targets that result in high CPU usage when using
    # multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
    && rm -f /lib/systemd/system/systemd*udev* \
    && rm -f /lib/systemd/system/getty.target

VOLUME ["/sys/fs/cgroup", "/tmp", "/run"]

ENTRYPOINT ["/lib/systemd/systemd"]
