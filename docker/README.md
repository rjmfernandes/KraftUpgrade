# Upgrade CP Docker Compose Install From Zookeeper to KRaft

We have adapted the guide https://docs.confluent.io/platform/7.6/installation/migrate-zk-kraft.html for the case of containers in a docker compose. 

**Important Note: This is more of a hacking exercise!**

The setup starts with 3 ZK and 1 Broker and ends up with 3 KRaft Controllers and 1 Broker. 

## Start

Execute:

```bash
cp compose0.yml compose.yml
docker compose up -d
```

If you check our docker compose the particularity is that we are overwriting [the launch script](./scripts/launch.sh) of docker image of Kafka to use explicitly [a specific properties file](./templates/kafka-broker.properties) (that we mapped on our [compose file](./compose0.yml)) for now pretty standard.

Create a topic:

```bash
kafka-topics --bootstrap-server localhost:19092 --topic test --create --partitions 1 --replication-factor 1
```

## Step 1: Retrieve the cluster ID

```bash
zookeeper-shell localhost:2181
```

And in the zookeeper shell execute:

```
get /cluster/id
```

And copy it to [.env file](./.env) for the CLUSTER_ID variable. We will need it for proper setup of KRaft controllers.

## Step 2-3: Provision KRaft controllers

Steps 2 and 3 of the original guide have been merged to make things work for containers. Basically to start the KRaft nodes from the docker images the storage needs to be already formatted with the CLUSTER_ID.

So now we need to execute:

```bash
cp compose2.yml compose.yml
docker compose up -d
```

The [new compose file](./compose2.yml) includes the controllers and in this case we are overwriting [the run script](./scripts/run.sh) of the docker image in order to execute the format of the storage (if it detects a CLUSTER_ID has been provided and the format action was never executed) before starting the kraft controller process. For that uses [a template of the configuration file](./templates/kafka-controller.properties) where variables are replaced in runtime according to each kraft controller container variables.

## Step 4: Enable migration on the brokers

Now we update [the configuration of the broker](compose4.yml) pointing to [a different configuration template file](./templates/kafka-broker-enable-migration.properties) that will enable the migration of the brokers. For that we execute:

```bash
cp compose4.yml compose.yml
docker compose up -d
```

It may happen that the broker restarts too fast and validation of the entry still being available on ZK causes it to fail. In this case just execute (maybe a couple of times more):

```bash
docker compose up -d
```

Once our broker has finished starting you can check the logs of controllers for the migration complete flag:

```bash
docker compose logs -f | grep 'Completed migration of metadata from ZooKeeper to KRaft.'
```

You may need to do a full restart to speed things up...

```bash
docker compose restart
```

But at some point if everything goes well the migration complete signaling line should show up on the logs for the master of the Kraft controllers.

We should also be able to list our topics still:

```bash
kafka-topics --bootstrap-server localhost:19092 --list
```

For now the cluster is in dual write mode writing at same time to ZK and KRaft nodes but broker is still using ZK.

## Step 5: Migrate the brokers

For migrating to Kraft:

```bash
cp compose5.yml compose.yml
docker compose up -d
```

Now [the new compose file](./compose5.yml) is making sure the broker is using [the updated Kraft configuration for the broker](./templates/kafka-broker-migrate.properties). After this our cluster is running in KRaft mode.

Ang again we can confirm the topics are all there by executing again:

```bash
kafka-topics --bootstrap-server localhost:19092 --list
```

## Step 6: Take KRaft controllers out of migration mode

For this execute:

```bash
docker compose down zookeeper1
docker compose down zookeeper2
docker compose down zookeeper3
cp compose6.yml compose.yml
docker compose up -d
```

Now we have removed the ZK entries from [the docker compose file](./compose6.yml) and the controllers configurations are now using [the external configuration files](./templates/controller3.properties) with migration mode deactivated. This is done so by using the same mechanism as for the case of broker on steps before: overwrite [launch](./scripts/launch.sh) from docker image and point to a mapped specific file.

Once again we can confirm all is fine by executing:

```bash
kafka-topics --bootstrap-server localhost:19092 --list
```

## Cleanup

To cleanup and come back to start just execute:

```bash
./scripts/clean.sh
```

For full cleanup of everything docker on your machine execute:

```bash
docker stop `docker ps -a -q` && docker rm -v `docker ps -a -q`
```

