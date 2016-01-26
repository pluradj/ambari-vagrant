# TinkerPop3 OLAP with GiraphGraphComputer

* [Configuration](#configuration)
* [Vertex Programs](#vertex-programs)
* [Troubleshooting](#troubleshooting)

## References

* Apache TinkerPop3 Docs: http://tinkerpop.apache.org/docs/3.1.0-incubating/

## Prerequisites

* [TinkerPop3 OLAP](AmbariTinkerPop.md) installed and configured

## Configuration

### Setup the environment for GiraphGraphComputer

```
export TP3_HOME=$HOME/apache-gremlin-console-3.1.0-incubating
export HADOOP_CONF_DIR=/etc/hadoop/conf
export CLASSPATH=$HADOOP_CONF_DIR
export HADOOP_GREMLIN_LIBS=$TP3_HOME/ext/giraph-gremlin/lib:$TP3_HOME/ext/tinkergraph-gremlin/lib
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

# Use external ZooKeeper instead of local ZooKeeper (optional)
giraph.zkList=u1401.ambari.apache.org:2181,u1402.ambari.apache.org:2181,u1403.ambari.apache.org:2181
# Let the YARN Resource Manager handle the MR2 job (any value other than local will do)
mapreduce.jobtracker.address=yarn
# Separate the workers and the master tasks
giraph.SplitMasterWorker=true
giraph.minWorkers=2
giraph.maxWorkers=2
```

* ./conf/hadoop/hadoop-grateful-gryo.properties

```
gremlin.graph=org.apache.tinkerpop.gremlin.hadoop.structure.HadoopGraph
gremlin.hadoop.jarsInDistributedCache=true
gremlin.hadoop.graphInputFormat=org.apache.tinkerpop.gremlin.hadoop.structure.io.gryo.GryoInputFormat
gremlin.hadoop.graphOutputFormat=org.apache.tinkerpop.gremlin.hadoop.structure.io.gryo.GryoOutputFormat
gremlin.hadoop.inputLocation=data/grateful-dead.kryo
gremlin.hadoop.outputLocation=output

# Use external ZooKeeper instead of local ZooKeeper (optional)
giraph.zkList=u1401.ambari.apache.org:2181,u1402.ambari.apache.org:2181,u1403.ambari.apache.org:2181
# Let the YARN Resource Manager handle the MR2 job (any value other than local will do)
mapreduce.jobtracker.address=yarn
# Separate the workers and the master tasks
giraph.SplitMasterWorker=true
giraph.minWorkers=2
giraph.maxWorkers=2
```

## Vertex Programs

### Gremlin traversal (TraversalVertexProgram)

```
./bin/gremlin.sh

graph = GraphFactory.open('conf/hadoop/hadoop-gryo.properties')
g = graph.traversal(computer(GiraphGraphComputer))
g.V().count()
g.V().out().out().values('name')
```

### PageRankVertexProgram example

```
./bin/gremlin.sh

graph = GraphFactory.open('conf/hadoop/hadoop-gryo.properties')
prvp = PageRankVertexProgram.build().create()
result = graph.compute(GiraphGraphComputer).program(prvp).submit().get()
result.memory().getRuntime()
result.memory().asMap()
g = result.graph().traversal(computer(GiraphGraphComputer))
g.V().valueMap('name', PageRankVertexProgram.PAGE_RANK)
```

### BulkLoaderVertexProgram example

```
./bin/gremlin.sh

readGraph = GraphFactory.open('conf/hadoop/hadoop-grateful-gryo.properties')
writeGraph = 'conf/tinkergraph-gryo.properties'
blvp = BulkLoaderVertexProgram.build().keepOriginalIds(false).userSuppliedIds(false).writeGraph(writeGraph).create(readGraph)
readGraph.compute(GiraphGraphComputer).workers(1).program(blvp).submit().get()
graph = GraphFactory.open(writeGraph)
g = graph.traversal()
g.V().valueMap()
graph.close()
```

## Troubleshooting

### The computer requires more workers than supported: 1 [max:0]

* Gremlin Console output

```
java.lang.IllegalStateException: The computer requires more workers than supported: 1 [max:0]
    at org.apache.tinkerpop.gremlin.process.computer.traversal.step.map.ComputerResultStep.processNextStart(ComputerResultStep.java:82)
    at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:140)
    at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:144)
    ...
Caused by: java.lang.IllegalArgumentException: The computer requires more workers than supported: 1 [max:0]
    at org.apache.tinkerpop.gremlin.process.computer.GraphComputer$Exceptions.computerRequiresMoreWorkersThanSupported(GraphComputer.java:238)
    at org.apache.tinkerpop.gremlin.hadoop.process.computer.AbstractHadoopGraphComputer.validateStatePriorToExecution(AbstractHadoopGraphComputer.java:117)
    at org.apache.tinkerpop.gremlin.giraph.process.computer.GiraphGraphComputer.submit(GiraphGraphComputer.java:116)
    at org.apache.tinkerpop.gremlin.process.computer.traversal.step.map.ComputerResultStep.processNextStart(ComputerResultStep.java:80)
    ...
```

* Discussion: The `HADOOP_CONF_DIR` is not found on the `CLASSPATH`

* Resolution: Exit the Gremlin Console, then add the `HADOOP_CONF_DIR` to the `CLASSPATH`. After restarting the Gremlin Console, use `hdfs.ls()` to verify files listed are from HDFS instead of the local filesystem.

```
gremlin> hdfs.ls()
==>rwx------ ambari-qa hdfs 0 (D) .staging
==>rwxrwx--- ambari-qa hdfs 0 (D) DistributedShell
==>rwxr-xr-x ambari-qa hdfs 0 (D) data
==>rwxrwx--- ambari-qa hdfs 0 (D) hadoop-gremlin-3.1.0-incubating-libs
==>rwxr-xr-x hdfs hdfs 1631 mapredsmokeinput
==>rwxr-xr-x ambari-qa hdfs 0 (D) mapredsmokeoutput
==>rwxr-xr-x ambari-qa hdfs 0 (D) output_
```

### HADOOP_GREMLIN_LIBS is not set

* Gremlin Console output

```
WARN  org.apache.tinkerpop.gremlin.giraph.process.computer.GiraphGraphComputer  - HADOOP_GREMLIN_LIBS is not set -- proceeding regardless
INFO  org.apache.hadoop.mapreduce.Job  - The url to track the job: http://u1402.ambari.apache.org:8088/proxy/application_1453821799726_0003/
INFO  org.apache.hadoop.mapreduce.Job  - Running job: job_1453821799726_0003
INFO  org.apache.hadoop.mapreduce.Job  - Job job_1453821799726_0003 running in uber mode : false
INFO  org.apache.hadoop.mapreduce.Job  -  map 0% reduce 0%
INFO  org.apache.hadoop.mapreduce.Job  - Job job_1453821799726_0003 failed with state FAILED due to: Application application_1453821799726_0003 failed 2 times due to AM Container for appattempt_1453821799726_0003_000002 exited with  exitCode: 1
For more detailed output, check application tracking page:http://u1402.ambari.apache.org:8088/cluster/app/application_1453821799726_0003Then, click on links to logs of each attempt.
Diagnostics: Exception from container-launch.
Container id: container_e01_1453821799726_0003_02_000001
Exit code: 1
Stack trace: ExitCodeException exitCode=1:
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
INFO  org.apache.hadoop.mapreduce.Job  - Counters: 0
java.lang.IllegalStateException: The GiraphGraphComputer job failed -- aborting all subsequent MapReduce jobs
```

* Resolution: Exit the Gremlin Console, then set `HADOOP_GREMLIN_LIBS`. After restarting the Gremlin Console, verify that `HADOOP_GREMLIN_LIBS` is set correctly.

```
./bin/gremlin.sh

         \,,,/
         (o o)
-----oOOo-(3)-oOOo-----
plugin activated: tinkerpop.server
plugin activated: tinkerpop.utilities
plugin activated: tinkerpop.giraph
INFO  org.apache.tinkerpop.gremlin.hadoop.structure.HadoopGraph  - HADOOP_GREMLIN_LIBS is set to: /home/ambari-qa/apache-gremlin-console-3.1.0-incubating/ext/giraph-gremlin/lib:/home/ambari-qa/apache-gremlin-console-3.1.0-incubating/ext/
plugin activated: tinkerpop.hadoop
plugin activated: tinkerpop.tinkergraph
gremlin>
```

### When using LocalJobRunner, must have only one worker since only 1 task at a time!

* Gremlin Console output

```
java.lang.IllegalStateException: java.lang.IllegalStateException: checkLocalJobRunnerConfiguration: When using LocalJobRunner, must have only one worker since only 1 task at a time!
    at org.apache.tinkerpop.gremlin.process.computer.traversal.step.map.ComputerResultStep.processNextStart(ComputerResultStep.java:82)
    at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:140)
    at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:144)
    ...
Caused by: java.util.concurrent.ExecutionException: java.lang.IllegalStateException: checkLocalJobRunnerConfiguration: When using LocalJobRunner, must have only one worker since only 1 task at a time!
    at java.util.concurrent.CompletableFuture.reportGet(CompletableFuture.java:357)
    at java.util.concurrent.CompletableFuture.get(CompletableFuture.java:1895)
    at org.apache.tinkerpop.gremlin.process.computer.traversal.step.map.ComputerResultStep.processNextStart(ComputerResultStep.java:80)
    ...
Caused by: java.lang.IllegalStateException: checkLocalJobRunnerConfiguration: When using LocalJobRunner, must have only one worker since only 1 task at a time!
    at org.apache.tinkerpop.gremlin.giraph.process.computer.GiraphGraphComputer.lambda$submit$4(GiraphGraphComputer.java:126)
    at java.util.concurrent.CompletableFuture$AsyncSupply.run(CompletableFuture.java:1590)
    at java.lang.Thread.run(Thread.java:745)
    ...
```

* Discussion: The [default value](https://hadoop.apache.org/docs/current/hadoop-mapreduce-client/hadoop-mapreduce-client-core/mapred-default.xml) for `mapreduce.jobtracker.address` is `local`. This means that jobs are run in-process as a single map and reduce task, not as a YARN job.

* Resolution: Configure the Giraph job for YARN to handle and split the tasks, or configure the Giraph job as single task.

```
# Option 1: YARN job
mapreduce.jobtracker.address=yarn
giraph.SplitMasterWorker=true
giraph.minWorkers=2
giraph.maxWorkers=2

# Option 2: single local job
mapreduce.jobtracker.address=local
giraph.SplitMasterWorker=false
giraph.minWorkers=1
giraph.maxWorkers=1
```

* Resolution: If you expect to always use YARN to run your Giraph jobs, you can set the `mapreduce.jobtracker.address` in the `mapred-site.xml`. After you restart all MapReduce and YARN services, the new default value will be active, and you do not need to specify `mapreduce.jobtracker.address` in the properties file.