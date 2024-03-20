# Upgrade CP From Zookeeper to KRaft with Ansible

We will be upgrading CP from ZK to KRaft using Ansible locally and following the guide: https://docs.confluent.io/ansible/current/ansible-migrate-kraft.html

# 0. Setup

The setup starts with 3 ZK and 1 Broker.

We have adapted the steps listed here: https://github.com/rjmfernandes/local-ansible-cp

Create the image (from the work by Jeff Geerling https://github.com/geerlingguy/docker-ubuntu2204-ansible):

```bash
docker build . -t my-geerlingguy-docker-ubuntu-ansible
```

Clone CP Ansible git repo:

```bash
git clone https://github.com/confluentinc/cp-ansible.git
```
Inside the repository you need to copy the playbooks to root:

```bash
cd cp-ansible
cp -fr playbooks/* .
```

Copy hosts.yml to cp-ansible.

```bash
cp ../hosts.yml .
```

Edit the variables of hosts.yml as the example here. Pay attention to the following variables:

```yml
    ansible_connection: docker
    ansible_user: root
    ansible_become: true
    ssl_enabled: false
    confluent.platform.ssl_required: false
    ansible_python_interpreter: /usr/bin/python3
    custom_java_path: /usr/lib/jvm/java-17-openjdk-arm64
```

You will also want to make sure the server instances in hosts.yml match the ones defined in the docker-compose.yml file (just like the example here). Keep commented out the kafka_controller entries in the hosts.yml.

Finally run the docker-compose from the root of the project:

```bash
cd ..
docker compose up -d
```

You will need to map the host names on your `/etc/hosts` file:

```
127.0.0.1 zk1
127.0.0.1 zk2
127.0.0.1 zk3
127.0.0.1 kafka1
127.0.0.1 kc1
127.0.0.1 kc2
127.0.0.1 kc3
```

Finally back to the cp-ansible cloned repository run:

```bash
cd cp-ansible
ansible-galaxy collection install git+https://github.com/confluentinc/cp-ansible.git,7.6.x
ansible-playbook ./all.yml -i hosts.yml
```

Create a topic:

```bash
kafka-topics --bootstrap-server kafka1:9092 --topic test --create --partitions 1 --replication-factor 1
```

For listing topics you can also execute:

```bash
kafka-topics --bootstrap-server kafka1:9092 --list
```

# 1-3. Enable migration flag / Add kafka_controller hosts / Run migration playbook

Copy [1-hosts.yml](./1-hosts.yml) as hosts.yml into the cp-ansible folder:

```bash
cp ../1-hosts.yml ./hosts.yml
```

It enables the `kraft_migration` and add the 3 kraft controllers hosts.

For running the migration playbook you can do in steps or at once.

### 3.1. Migrate in 2 Steps

Migrate to Dual Write Mode:

```bash
ansible-playbook -i hosts.yml confluent.platform.ZKtoKraftMigration.yml \
  --tags migrate_to_dual_write
```

Validate data migrated:

```bash
kafka-topics --bootstrap-server kafka1:9092 --list
```

**Note: At this point you could still rollback to ZK. For that check:** https://docs.confluent.io/ansible/current/ansible-migrate-kraft.html#roll-back-to-zk 

Complete migration:

```bash
ansible-playbook -i hosts.yml confluent.platform.ZKtoKraftMigration.yml \
  --tags migrate_to_kraft
```

Validate again:

```bash
kafka-topics --bootstrap-server kafka1:9092 --list
```


### 3.2. Migrate in one step

```bash
ansible-playbook -i hosts.yml confluent.platform.ZKtoKraftMigration.yml
```

Validate:

```bash
kafka-topics --bootstrap-server kafka1:9092 --list
```

## 4 - Stop ZK 

Now you can execute:

```bash
cd ..
docker compose down -v zk1 zk2 zk3
cp 4-hosts.yml cp-ansible/hosts.yml
```

(The last command just updates the hosts.yml without ZK entries.)

And validate:

```bash
kafka-topics --bootstrap-server kafka1:9092 --list
```

## Cleanup

To cleanup and come back to start just execute:

```bash
docker compose down -v 
rm -fr cp-ansible
```

