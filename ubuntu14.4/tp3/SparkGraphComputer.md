# TinkerPop3 OLAP with SparkGraphComputer

* [Configuration](#configuration)
* [Vertex Programs](#vertex-programs)
* [Troubleshooting](#troubleshooting)

## References

* Apache TinkerPop3 Docs: http://tinkerpop.apache.org/docs/3.1.0-incubating/

## Prerequisites

* [TinkerPop3 OLAP](AmbariTinkerPop.md) installed and configured

## Configuration

### Setup the spark-assembly.jar

```
sudo su - ambari-qa
wget http://apache.mirrors.tds.net/spark/spark-1.5.1/spark-1.5.1-bin-hadoop2.6.tgz
tar -xvf spark-1.5.1-bin-hadoop2.6.tgz
cd spark-1.5.1-bin-hadoop2.6/
hdfs dfs -mkdir -p share/lib/spark/
hdfs dfs -put lib/spark-assembly-1.5.1-hadoop2.6.0.jar share/lib/spark/
```

### Setup the environment for SparkGraphComputer

```
export SPARK_HOME=$HOME/spark-1.5.1-bin-hadoop2.6
export TP3_HOME=$HOME/apache-gremlin-console-3.1.0-incubating
export HADOOP_CONF_DIR=/etc/hadoop/conf
export CLASSPATH=$HADOOP_CONF_DIR
export HADOOP_GREMLIN_LIBS=$TP3_HOME/ext/spark-gremlin/lib:$TP3_HOME/ext/tinkergraph-gremlin/lib

cp $SPARK_HOME/lib/spark-assembly-1.5.1-hadoop2.6.0.jar $TP3_HOME/ext/spark-gremlin/plugin/
```

### Setup the properties files

* ./conf/hadoop/hadoop-gryo.properties

```
gremlin.graph=org.apache.tinkerpop.gremlin.hadoop.structure.HadoopGraph
gremlin.hadoop.jarsInDistributedCache=true
gremlin.hadoop.graphInputFormat=org.apache.tinkerpop.gremlin.hadoop.structure.io.gryo.GryoInputFormat
gremlin.hadoop.graphOutputFormat=org.apache.tinkerpop.gremlin.hadoop.structure.io.gryo.GryoOutputFormat
gremlin.hadoop.inputLocation=data/tinkerpop-modern.kryo
gremlin.hadoop.outputLocation=output

# use yarn-client, standalone master url (spark://23.195.26.187:7077), or local
spark.master=yarn-client
# Cache the Spark jar in HDFS so that it doesn't need to be distributed each time an application runs (optional)
spark.yarn.jar=hdfs://u1401.ambari.apache.org:8020/user/ambari-qa/share/lib/spark/spark-assembly-1.5.1-hadoop2.6.0.jar
# additional Hadoop distro variables required for YARN ApplicationMaster
spark.yarn.am.extraJavaOptions=-Dhdp.version=2.3.4.0-3485 -Djava.library.path=/usr/hdp/2.3.4.0-3485/hadoop/lib/native
# keep executor memory within YARN Container bounds
spark.executor.memory=512m
```

* ./conf/hadoop/hadoop-grateful-gryo.properties

```
gremlin.graph=org.apache.tinkerpop.gremlin.hadoop.structure.HadoopGraph
gremlin.hadoop.jarsInDistributedCache=true
gremlin.hadoop.graphInputFormat=org.apache.tinkerpop.gremlin.hadoop.structure.io.gryo.GryoInputFormat
gremlin.hadoop.graphOutputFormat=org.apache.tinkerpop.gremlin.hadoop.structure.io.gryo.GryoOutputFormat
gremlin.hadoop.inputLocation=data/grateful-dead.kryo
gremlin.hadoop.outputLocation=output

# use yarn-client, standalone master url (spark://23.195.26.187:7077), or local
spark.master=yarn-client
# Cache the Spark jar in HDFS so that it doesn't need to be distributed each time an application runs (optional)
spark.yarn.jar=hdfs://u1401.ambari.apache.org:8020/user/ambari-qa/share/lib/spark/spark-assembly-1.5.1-hadoop2.6.0.jar
# additional Hadoop distro variables required for YARN ApplicationMaster
spark.yarn.am.extraJavaOptions=-Dhdp.version=2.3.4.0-3485 -Djava.library.path=/usr/hdp/2.3.4.0-3485/hadoop/lib/native
# keep executor memory within YARN Container bounds
spark.executor.memory=512m
```

## Vertex Programs

### Gremlin traversal (TraversalVertexProgram)

```
./bin/gremlin.sh

graph = GraphFactory.open('conf/hadoop/hadoop-gryo.properties')
g = graph.traversal(computer(SparkGraphComputer))
g.V().count()
g.V().out().out().values('name')
```

### PageRankVertexProgram example

```
./bin/gremlin.sh

graph = GraphFactory.open('conf/hadoop/hadoop-gryo.properties')
prvp = PageRankVertexProgram.build().create()
result = graph.compute(SparkGraphComputer).program(prvp).submit().get()
result.memory().getRuntime()
result.memory().asMap()
g = result.graph().traversal(computer(SparkGraphComputer))
g.V().valueMap('name', PageRankVertexProgram.PAGE_RANK)
```

### BulkLoaderVertexProgram example

```
./bin/gremlin.sh

readGraph = GraphFactory.open('conf/hadoop/hadoop-grateful-gryo.properties')
writeGraph = 'conf/tinkergraph-gryo.properties'
blvp = BulkLoaderVertexProgram.build().keepOriginalIds(false).userSuppliedIds(false).writeGraph(writeGraph).create(readGraph)
readGraph.compute(SparkGraphComputer).workers(1).program(blvp).submit().get()
graph = GraphFactory.open(writeGraph)
g = graph.traversal()
g.V().valueMap()
graph.close()
```

## Troubleshooting

### A master URL must be set in your configuration

* Gremlin Console output

```
ERROR org.apache.spark.SparkContext  - Error initializing SparkContext.
org.apache.spark.SparkException: A master URL must be set in your configuration
    at org.apache.spark.SparkContext.<init>(SparkContext.scala:394)
    at org.apache.spark.SparkContext$.getOrCreate(SparkContext.scala:2256)
    at org.apache.spark.SparkContext.getOrCreate(SparkContext.scala)
    at org.apache.tinkerpop.gremlin.spark.process.computer.SparkGraphComputer.lambda$submit$21(SparkGraphComputer.java:137)
    at java.util.concurrent.CompletableFuture$AsyncSupply.run(CompletableFuture.java:1590)
    at java.lang.Thread.run(Thread.java:745)
```

* Resolution: Set a `spark.master`

```
# Option 1: YARN client
spark.master=yarn-client
# Option 2: Master URL for standalone Spark cluster
spark.master=spark://u1401.ambari.apache.org:7077
# Option 3: Local mode with 4 workers
spark.master=local[4]
```

### `yarn-client` java.lang.ExceptionInInitializerError

* Gremlin Console output

```
java.lang.IllegalStateException: java.lang.ExceptionInInitializerError
    at org.apache.tinkerpop.gremlin.process.computer.traversal.step.map.ComputerResultStep.processNextStart(ComputerResultStep.java:82)
    at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:140)
    at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:144)
    ...
Caused by: java.util.concurrent.ExecutionException: java.lang.ExceptionInInitializerError
    at java.util.concurrent.CompletableFuture.reportGet(CompletableFuture.java:357)
    at java.util.concurrent.CompletableFuture.get(CompletableFuture.java:1895)
    at org.apache.tinkerpop.gremlin.process.computer.traversal.step.map.ComputerResultStep.processNextStart(ComputerResultStep.java:80)
    ...
Caused by: java.lang.ExceptionInInitializerError
    at org.apache.spark.util.Utils$.getSparkOrYarnConfig(Utils.scala:2042)
    at org.apache.spark.storage.BlockManager.<init>(BlockManager.scala:97)
    at org.apache.spark.storage.BlockManager.<init>(BlockManager.scala:173)
    at org.apache.spark.SparkEnv$.create(SparkEnv.scala:345)
    ...
Caused by: org.apache.spark.SparkException: Unable to load YARN support
    at org.apache.spark.deploy.SparkHadoopUtil$.liftedTree1$1(SparkHadoopUtil.scala:392)
    at org.apache.spark.deploy.SparkHadoopUtil$.<init>(SparkHadoopUtil.scala:387)
    at org.apache.spark.deploy.SparkHadoopUtil$.<clinit>(SparkHadoopUtil.scala)
    ...
Caused by: java.lang.ClassNotFoundException: org.apache.spark.deploy.yarn.YarnSparkHadoopUtil
    at java.net.URLClassLoader.findClass(URLClassLoader.java:381)
    at java.lang.ClassLoader.loadClass(ClassLoader.java:424)
    ...
```

* Resolution: ensure the `spark-assembly-*.jar` is on the classpath

### `yarn-client` unable to launch application master

* Gremlin Console output

```
ERROR org.apache.spark.SparkContext  - Error initializing SparkContext.
org.apache.spark.SparkException: Yarn application has already ended! It might have been killed or unable to launch application master.
    at org.apache.spark.scheduler.cluster.YarnClientSchedulerBackend.waitForApplication(YarnClientSchedulerBackend.scala:123)
    at org.apache.spark.scheduler.cluster.YarnClientSchedulerBackend.start(YarnClientSchedulerBackend.scala:63)
    at org.apache.spark.scheduler.TaskSchedulerImpl.start(TaskSchedulerImpl.scala:144)
    at org.apache.spark.SparkContext.<init>(SparkContext.scala:523)
    ...
ERROR org.apache.spark.util.Utils  - Uncaught exception in thread Thread-10
java.lang.NullPointerException
    at org.apache.spark.network.netty.NettyBlockTransferService.close(NettyBlockTransferService.scala:152)
    at org.apache.spark.storage.BlockManager.stop(BlockManager.scala:1228)
    at org.apache.spark.SparkEnv.stop(SparkEnv.scala:100)
    ...
org.apache.spark.SparkException: Yarn application has already ended! It might have been killed or unable to launch application master.
```

* YARN Job Diagnostics

Click on the `applicationId` for the failed YARN job from the YARN ResourceMananger UI http://u1402.ambari.apache.org:8088/cluster

```
Application application_1453821799726_0021 failed 2 times due to AM Container for appattempt_1453821799726_0021_000002 exited with exitCode: 1
For more detailed output, check application tracking page:http://u1402.ambari.apache.org:8088/cluster/app/application_1453821799726_0021Then, click on links to logs of each attempt.
Diagnostics: Exception from container-launch.
Container id: container_e01_1453821799726_0021_02_000001
Exit code: 1
Exception message: /hadoop/yarn/local/usercache/ambari-qa/appcache/application_1453821799726_0021/container_e01_1453821799726_0021_02_000001/launch_container.sh: line 24: $PWD:$PWD/__spark_conf__:$PWD/__spark__.jar:$HADOOP_CONF_DIR:/usr/hdp/current/hadoop-client/*:/usr/hdp/current/hadoop-client/lib/*:/usr/hdp/current/hadoop-hdfs-client/*:/usr/hdp/current/hadoop-hdfs-client/lib/*:/usr/hdp/current/hadoop-yarn-client/*:/usr/hdp/current/hadoop-yarn-client/lib/*:$PWD/mr-framework/hadoop/share/hadoop/mapreduce/*:$PWD/mr-framework/hadoop/share/hadoop/mapreduce/lib/*:$PWD/mr-framework/hadoop/share/hadoop/common/*:$PWD/mr-framework/hadoop/share/hadoop/common/lib/*:$PWD/mr-framework/hadoop/share/hadoop/yarn/*:$PWD/mr-framework/hadoop/share/hadoop/yarn/lib/*:$PWD/mr-framework/hadoop/share/hadoop/hdfs/*:$PWD/mr-framework/hadoop/share/hadoop/hdfs/lib/*:$PWD/mr-framework/hadoop/share/hadoop/tools/lib/*:/usr/hdp/${hdp.version}/hadoop/lib/hadoop-lzo-0.6.0.${hdp.version}.jar:/etc/hadoop/conf/secure: bad substitution
Stack trace: ExitCodeException exitCode=1: /hadoop/yarn/local/usercache/ambari-qa/appcache/application_1453821799726_0021/container_e01_1453821799726_0021_02_000001/launch_container.sh: line 24: $PWD:$PWD/__spark_conf__:$PWD/__spark__.jar:$HADOOP_CONF_DIR:/usr/hdp/current/hadoop-client/*:/usr/hdp/current/hadoop-client/lib/*:/usr/hdp/current/hadoop-hdfs-client/*:/usr/hdp/current/hadoop-hdfs-client/lib/*:/usr/hdp/current/hadoop-yarn-client/*:/usr/hdp/current/hadoop-yarn-client/lib/*:$PWD/mr-framework/hadoop/share/hadoop/mapreduce/*:$PWD/mr-framework/hadoop/share/hadoop/mapreduce/lib/*:$PWD/mr-framework/hadoop/share/hadoop/common/*:$PWD/mr-framework/hadoop/share/hadoop/common/lib/*:$PWD/mr-framework/hadoop/share/hadoop/yarn/*:$PWD/mr-framework/hadoop/share/hadoop/yarn/lib/*:$PWD/mr-framework/hadoop/share/hadoop/hdfs/*:$PWD/mr-framework/hadoop/share/hadoop/hdfs/lib/*:$PWD/mr-framework/hadoop/share/hadoop/tools/lib/*:/usr/hdp/${hdp.version}/hadoop/lib/hadoop-lzo-0.6.0.${hdp.version}.jar:/etc/hadoop/conf/secure: bad substitution
at org.apache.hadoop.util.Shell.runCommand(Shell.java:576)
at org.apache.hadoop.util.Shell.run(Shell.java:487)
at org.apache.hadoop.util.Shell$ShellCommandExecutor.execute(Shell.java:753)
at org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor.launchContainer(DefaultContainerExecutor.java:212)
at org.apache.hadoop.yarn.server.nodemanager.containermanager.launcher.ContainerLaunch.call(ContainerLaunch.java:302)
at org.apache.hadoop.yarn.server.nodemanager.containermanager.launcher.ContainerLaunch.call(ContainerLaunch.java:82)
at java.util.concurrent.FutureTask.run(FutureTask.java:266)
at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
at java.lang.Thread.run(Thread.java:745)
Container exited with a non-zero exit code 1
Failing this attempt. Failing the application.
```

* Resolution: ensure `gremlin.sh` has the `-Dhdp.version` for the `JAVA_OPTIONS`

```
JAVA_OPTIONS="$JAVA_OPTIONS -Dhdp.version=2.3.4.0-3485 -Djava.library.path=/usr/hdp/2.3.4.0-3485/hadoop/lib/native"
```

### `yarn-client` Job cancelled because SparkContext was shut down

* Gremlin Console output

```
WARN  org.apache.spark.scheduler.cluster.YarnSchedulerBackend$YarnSchedulerEndpoint  - ApplicationMaster has disassociated: 192.168.14.102:49463
WARN  org.apache.spark.scheduler.cluster.YarnSchedulerBackend$YarnSchedulerEndpoint  - ApplicationMaster has disassociated: 192.168.14.102:49463
WARN  akka.remote.ReliableDeliverySupervisor  - Association with remote system [akka.tcp://sparkYarnAM@192.168.14.102:49463] has failed, address is now gated for [5000] ms. Reason: [Disassociated]
ERROR org.apache.spark.scheduler.cluster.YarnClientSchedulerBackend  - Yarn application has already exited with state FINISHED!
org.apache.spark.SparkException: Job cancelled because SparkContext was shut down
Display stack trace? [yN] y
java.lang.IllegalStateException: org.apache.spark.SparkException: Job cancelled because SparkContext was shut down
    at org.apache.tinkerpop.gremlin.process.computer.traversal.step.map.ComputerResultStep.processNextStart(ComputerResultStep.java:82)
    at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:140)
    at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:144)
    at org.apache.tinkerpop.gremlin.console.Console$_closure3.doCall(Console.groovy:205)
    ...
Caused by: java.util.concurrent.ExecutionException: org.apache.spark.SparkException: Job cancelled because SparkContext was shut down
    at java.util.concurrent.CompletableFuture.reportGet(CompletableFuture.java:357)
    at java.util.concurrent.CompletableFuture.get(CompletableFuture.java:1895)
    at org.apache.tinkerpop.gremlin.process.computer.traversal.step.map.ComputerResultStep.processNextStart(ComputerResultStep.java:80)
    ... 42 more
Caused by: org.apache.spark.SparkException: Job cancelled because SparkContext was shut down
    at org.apache.spark.scheduler.DAGScheduler$$anonfun$cleanUpAfterSchedulerStop$1.apply(DAGScheduler.scala:703)
    at org.apache.spark.scheduler.DAGScheduler$$anonfun$cleanUpAfterSchedulerStop$1.apply(DAGScheduler.scala:702)
    at scala.collection.mutable.HashSet.foreach(HashSet.scala:79)
    ...
```

* YARN logs

Find the `applicationId` for the failed YARN job from the YARN ResourceMananger UI http://u1402.ambari.apache.org:8088/cluster

```
yarn logs -applicationId application_1453486142899_0024

Stack trace: ExitCodeException exitCode=1: /hadoop/yarn/local/usercache/ambari-qa/appcache/application_1453821799726_0012/container_e01_1453821799726_0012_01_000005/launch_container.sh: line 22:
  $PWD:$PWD/__spark__.jar:$HADOOP_CONF_DIR:
  /usr/hdp/current/hadoop-client/*:/usr/hdp/current/hadoop-client/lib/*:
  /usr/hdp/current/hadoop-hdfs-client/*:/usr/hdp/current/hadoop-hdfs-client/lib/*:
  /usr/hdp/current/hadoop-yarn-client/*:/usr/hdp/current/hadoop-yarn-client/lib/*:
  $PWD/mr-framework/hadoop/share/hadoop/mapreduce/*:$PWD/mr-framework/hadoop/share/hadoop/mapreduce/lib/*:
  $PWD/mr-framework/hadoop/share/hadoop/common/*:$PWD/mr-framework/hadoop/share/hadoop/common/lib/*:
  $PWD/mr-framework/hadoop/share/hadoop/yarn/*:$PWD/mr-framework/hadoop/share/hadoop/yarn/lib/*:
  $PWD/mr-framework/hadoop/share/hadoop/hdfs/*:$PWD/mr-framework/hadoop/share/hadoop/hdfs/lib/*:
  $PWD/mr-framework/hadoop/share/hadoop/tools/lib/*:
  /usr/hdp/${hdp.version}/hadoop/lib/hadoop-lzo-0.6.0.${hdp.version}.jar:
  /etc/hadoop/conf/secure: bad substitution

    at org.apache.hadoop.util.Shell.runCommand(Shell.java:576)
    at org.apache.hadoop.util.Shell.run(Shell.java:487)
    at org.apache.hadoop.util.Shell$ShellCommandExecutor.execute(Shell.java:753)
    at org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor.launchContainer(DefaultContainerExecutor.java:212)
    at org.apache.hadoop.yarn.server.nodemanager.containermanager.launcher.ContainerLaunch.call(ContainerLaunch.java:302)
    at org.apache.hadoop.yarn.server.nodemanager.containermanager.launcher.ContainerLaunch.call(ContainerLaunch.java:82)
    at java.util.concurrent.FutureTask.run(FutureTask.java:266)
    at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
    at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
    at java.lang.Thread.run(Thread.java:745)


Container exited with a non-zero exit code 1

16/01/26 18:24:38 INFO yarn.ApplicationMaster: Final app status: FAILED, exitCode: 11, (reason: Max number of executor failures reached)
16/01/26 18:24:41 INFO util.ShutdownHookManager: Shutdown hook called
```

* Resolution: ensure `hdp.version` is passed to the YARN ApplicationMaster process

```
spark.yarn.am.extraJavaOptions=-Dhdp.version=2.3.4.0-3485 -Djava.library.path=/usr/hdp/2.3.4.0-3485/hadoop/lib/native
```

### `yarn-client` Required executor memory is above the max threshold

* Gremlin Console output

```
ERROR org.apache.spark.SparkContext  - Error initializing SparkContext.
java.lang.IllegalArgumentException: Required executor memory (1024+384 MB) is above the max threshold (1024 MB) of this cluster! Please increase the value of 'yarn.scheduler.maximum-allocation-mb'.
```

* Discussion: The required executor memory is the executor memory (`spark.executor.memory` -- 1024 MB default) plus the overhead (`spark.yarn.executor.memoryOverhead` -- 384 MB default or 10% executor memory if larger). Max threshold is bound by the YARN maximum container size (`yarn.scheduler.maximum-allocation-mb`): 1024 MB.

* Resolution: Set executor memory to 512m so that the required executor memory total (512+384 MB) fits under the max threshold.

```
spark.executor.memory=512m
```

### `yarn-cluster` yarn-cluster mode doesn't work with SparkGraphComputer

* Gremlin Console output

```
ERROR org.apache.spark.SparkContext  - Error initializing SparkContext.
org.apache.spark.SparkException: Detected yarn-cluster mode, but isn't running on a cluster. Deployment to YARN is not supported directly by SparkContext. Please use spark-submit.
```

* [StackOverflow](http://stackoverflow.com/questions/31327275/pyspark-on-yarn-cluster-mode): Fundamentally, if you're sharing any in-memory state between your web app and your Spark code, that means you won't be able to chop off the Spark portion to run inside a YARN container, which is what yarn-cluster tries to do.
* [Blog](http://blog.sequenceiq.com/blog/2014/08/22/spark-submit-in-java/) - Submit a Spark job to YARN from Java code: Use the org.apache.spark.deploy.yarn.Client directly in your Java application and make sure that every required environment variable is set properly.
