# Upgrade CP From Zookeeper to KRaft with Ansible

We will be upgrading CP from ZK to KRaft using Ansible locally and following the guide: https://docs.confluent.io/ansible/current/ansible-migrate-kraft.html

# 0. Setup

The setup starts with 3 ZK and 1 Broker.

We have adapted the steps listed here: https://github.com/rjmfernandes/local-ansible-cp

Then, start the docker conatiners. Note, that `docker compose` will automatically create an image (derived from the work by Jeff Geerling https://github.com/geerlingguy/docker-ubuntu2204-ansible). This will take some time, though:

```bash
docker compose up -d
```

While waiting for docker to finish, set up the next things.

If you are not using the version of the config file provided in this environment, edit the variables of hosts.yml as in the example here. Pay attention to the following variables:

```yml
    ansible_connection: docker
    ansible_user: root
    ansible_become: true
    ssl_enabled: false
    confluent.platform.ssl_required: false
    ansible_python_interpreter: /usr/bin/python3
    custom_java_path: /usr/lib/jvm/java-17-openjdk-arm64
```

Please also have a look at the file `ansible.cfg` which will be mounted to the special docker container called `ansible` we use to run the playbooks.

You will also want to make sure the server instances in hosts.yml match the ones defined in the docker-compose.yml file (just like the example here). Keep commented out the kafka_controller entries in the hosts.yml.

Finally back to the `ansible` sub folder, we use `docker compose` for convenience to run the playbook inside of the container `ansible` which was just spawned for the purpose of running ansible commands:

```bash
docker compose exec ansible ansible-playbook -i /etc/ansible/hosts.yml confluent.platform.all
```

Create a topic:

```bash
docker compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --topic test --create --partitions 1 --replication-factor 1
```

For listing topics you can also execute:

```bash
docker compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --list
```

# 1-3. Enable migration flag / Add kafka_controller hosts / Run migration playbook

Copy [1-hosts.yml](./1-hosts.yml) as hosts.yml into the cp-ansible folder (you can always get the original version back by running `git checkout hosts.yml`):

```bash
cp 1-hosts.yml hosts.yml
```

It enables the `kraft_migration` and add the 3 kraft controllers hosts.

For running the migration playbook you can do in steps or at once.

### 3.1. Migrate in 2 Steps

Migrate to Dual Write Mode:

```bash
docker compose exec ansible ansible-playbook -i /etc/ansible/hosts.yml confluent.platform.ZKtoKraftMigration.yml --tags migrate_to_dual_write
```

Validate data migrated:

```bash
docker compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --list
```

**Note: At this point you could still rollback to ZK. For that check:** https://docs.confluent.io/ansible/current/ansible-migrate-kraft.html#roll-back-to-zk 

Complete migration:

```bash
docker compose exec ansible ansible-playbook -i /etc/ansible/hosts.yml confluent.platform.ZKtoKraftMigration.yml   --tags migrate_to_kraft
```

Validate again:

```bash
docker compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --list
```


### 3.2. Migrate in one step

```bash
docker compose exec ansible ansible-playbook -i /etc/ansible/hosts.yml confluent.platform.ZKtoKraftMigration.yml
```

Validate:

```bash
docker compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --list
```

## 4 - Stop ZK 

Now you can execute:

```bash
cd ..
docker compose down -v zk1 zk2 zk3
cp 4-hosts.yml hosts.yml
```

(The last command just updates the hosts.yml without ZK entries.)

And validate:

```bash
docker compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --list
```

## Cleanup

To cleanup and come back to start just execute:

```bash
docker compose down -v 
```

Resetting your git workspace can be done as usual by running:

```
git reset --hard main
```
