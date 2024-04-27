# Upgrade CP From Zookeeper to KRaft with CFK

We will be using kind locally and following the guide: https://docs.confluent.io/operator/current/co-migrate-kraft.html 

# 0. Setup

The setup starts with 3 ZK and 1 Broker.

Let's create cluster and deploy the dashboard:

```bash
kind create cluster
k apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml --context kind-kind
k create serviceaccount -n kubernetes-dashboard admin-user
k create clusterrolebinding -n kubernetes-dashboard admin-user --clusterrole cluster-admin --serviceaccount=kubernetes-dashboard:admin-user
token=$(kubectl -n kubernetes-dashboard create token admin-user)
echo $token
k proxy
```

Use the token shown on response of command before to access the dashboard at:

```bash
open http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/\#/workloads\?namespace\=_all
```

Set the default namespace confluent and install the operator:

```bash
kubectl create namespace confluent
kubectl config set-context --current --namespace=confluent
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update
helm upgrade --install \
  confluent-operator confluentinc/confluent-for-kubernetes \
  --set kRaftEnabled=false
```

Check pods (typically wait till all pods are ready before moving to every next step):

```bash
kubectl get pods
```

Deploy the cluster:

```bash
kubectl apply -f confluent-platform.yaml
```

Forward the port of kafka broker:

```bash
kubectl port-forward kafka-0 9092:9092
```

Make sure to have on /etc/hosts an entry as this one: 
`127.0.0.1 kafka-0.kafka.confluent.svc.cluster.local`

In another terminal create a topic:

```bash
kafka-topics --bootstrap-server kafka-0.kafka.confluent.svc.cluster.local:9092 --topic test --create --partitions 1 --replication-factor 1
```

For listing topics you can also execute:

```bash
kafka-topics --bootstrap-server kafka-0.kafka.confluent.svc.cluster.local:9092 --list
```

# 1. Enable the TRACE level logging for metadata migration.

Adding the trace log to our broker:
`log4j.logger.org.apache.kafka.metadata.migration=TRACE`

```bash
kubectl apply -f 1-kafka-enable-trace-log.yaml
```

# 2. Create KRaftController CRs

```bash
kubectl apply -f 2-controller.yaml
```

# 3-5. Create KRaftMigrationJob / Monitor migration process / Dual Write phase

We have merged those steps in the guide here. First create the migration job:

```bash
kubectl apply -f 3-migration-job.yaml
```

Right after start monitoring the migration job:

```bash
kubectl get kraftmigrationjob kraftmigrationjob -n confluent -oyaml -w
```

On another terminal check pods:

```bash
kubectl get pods
```

You should see pods for controllers getting created and pods restarting (here it's where the KRaft controllers are deployed).

Finally on the terminal you were monitoring the migration process you should see:

```
message: KRaft migration workflow in dual write mode. Kafka cluster is currently
      writing metadata to both KRaftControllers as well as ZK nodes.Migration is currently
      in Paused state. Please apply platform.confluent.io/kraft-migration-trigger-finalize-to-kraft
      to complete the migration and moving cluster to KRaft mode completely or apply
      platform.confluent.io/kraft-migration-trigger-rollback-to-zk annotation to rollbackToZk
      cluster to Zk
```

We are in Dual Write phase. 

## In case of rollback (alternative step 7 in guide)

**Rollback to ZK can only be done till here.**

Note: In case of rollback check https://docs.confluent.io/operator/current/co-migrate-kraft.html#co-rollback-to-zookeeper else complete next steps.

# 6. Complete Migration Process

Moving our cluster to KRaft mode:

```bash
kubectl annotate kraftmigrationjob kraftmigrationjob \
  platform.confluent.io/kraft-migration-trigger-finalize-to-kraft=true \
  --namespace confluent
```

Check pods and wait for broker and KRaft controllers roll to complete:

```bash
kubectl get pods
```

At the end you should see on the terminal monitoring the migration log:

```
message: KRaft Migration is completed, please follow these next steps:1. Download
      the updated kafka and kRaftController CRsand Update your CI/CD or local representation
      as necessary.2. Release the migration CR lock using following command (post
      step 2) `kubectl annotate kmj <kmj-cr-name> -n <namespace> platform.confluent.io/kraft-migration-release-cr-lock=true
      --overwrite`3. Zookeeper nodes won't be removed by CFK, Please make sure to
      remove these nodes.
```

# 8. Remove migration process lock on resources

We can now also remove the migration process lock:

```bash
kubectl annotate kraftmigrationjob kraftmigrationjob \
  platform.confluent.io/kraft-migration-release-cr-lock=true \
  --namespace confluent
```

# 9. Update your CI/CD as necessary

The migration job modifies the yaml representation of Kafka and KRaft CRs. For downloading the updated definitions:

```bash
kubectl get kafka <Kafka CR name> -n <namespace> -oyaml > updated_kafka.yaml

kubectl get kraftcontroller <KRaftcontroller CR name> -n <namespace> -oyaml > updated_kraftcontroller.yaml
```

# 10. Remove ZK

Finally we can remove ZK nodes:

```bash
kubectl delete -f 10-zk.yaml
```

Check pods and confirm only Kafka and KRaft controllers are running:

```bash
kubectl get pods
```

Forward the port of kafka broker:

```bash
kubectl port-forward kafka-0 9092:9092
```

And list topics:

```bash
kafka-topics --bootstrap-server kafka-0.kafka.confluent.svc.cluster.local:9092 --list
```

Confirm the test topic firtst created is listed.

# Cleanup

```bash
kind delete cluster
```