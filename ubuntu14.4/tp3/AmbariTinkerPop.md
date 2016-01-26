# TinkerPop3 OLAP with Apache Ambari

* [Install Ambari Server](#install-ambari-server)
* [Build a Cluster](#build-a-cluster)
* [TinkerPop3 OLAP](#tinkerpop3-olap)
  * [GiraphGraphComputer](GiraphGraphComputer.md)
  * [SparkGraphComputer](SparkGraphComputer.md)

## References

* Amabari Quick Start Guide: https://cwiki.apache.org/confluence/display/AMBARI/Quick+Start+Guide
* Apache TinkerPop3 Docs: http://tinkerpop.apache.org/docs/3.1.0-incubating/

## Prerequisites

* Install VirtualBox: https://www.virtualbox.org/wiki/Downloads
* Install Vagrant: https://www.vagrantup.com/downloads.html


## Install Ambari Server

Start 3 Ubuntu 14.04 VMs. 3 VMs with 3GB RAM each seems to be a good number with 16GB of RAM without taxing the system too much for small jobs.

```
./up.sh 3
```

Log into the Ambari Server VM, then download the repository file so that `ambari-server` can be installed.

```
vagrant ssh u1401
sudo su -
wget http://public-repo-1.hortonworks.com/ambari/ubuntu14/2.x/updates/2.2.0.0/ambari.list -O /etc/apt/sources.list.d/ambari.list
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com B9733A7A07513CAD
apt-get update

# Install Ambari Server and Ambari Agent
apt-get install ambari-server -y
ambari-server setup -s
ambari-server start
```

## Build a Cluster

Log into the Ambari Console

* Ambari Console: http://localhost:8080
* Username: admin
* Password: admin

Create a Cluster - Launch Install Wizard

Name your cluster: Grembari

Select Stack: HDP 2.3

Install Options:
* Target Hosts: u140[1-3].ambari.apache.org
* Provide SSH Private Key:
  * File: ambari-vagrant/ubuntu14.4/insecure_private_key
  * SSH User Account: vagrant

Choose Services:
* HDFS 2.7.1.2.3
* YARN + MapReduce2 2.7.1.2.3
* ZooKeeper 3.4.6.2.3

Assign Masters:
* u1401: NameNode, ZooKeeper Server
* u1402: SNameNode, History Server, App Timeline Server, Resource Manager, ZooKeeper Server
* u1403: ZooKeeper Server

Assign Slaves and Clients:
* DataNode: all
* NFSGateway: none
* NodeManager: all
* Client: all

Install, Start, and Test

Summary

Key Locations

```
# Java
export JAVA_HOME=/usr/jdk64/jdk1.8.0_60

# Hadoop
export HDP_VERSION=2.3.4.0-3485
export HADOOP_HOME=/usr/hdp/$HDP_VERSION/hadoop
export LD_LIBRARY_PATH=$HADOOP_HOME/lib/native
export HADOOP_CONF_DIR=/etc/hadoop/conf
export CLASSPATH=$HADOOP_CONF_DIR

# put java and hdfs on the PATH
export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$PATH
```

## TinkerPop3 OLAP

Download and unzip the Gremlin Console

```
sudo su - ambari-qa
curl -O http://apache.mirrors.tds.net/incubator/tinkerpop/3.1.0-incubating/apache-gremlin-console-3.1.0-incubating-bin.zip
unzip -q apache-gremlin-console-3.1.0-incubating-bin.zip
cd apache-gremlin-console-3.1.0-incubating
```

Upload the data files to HDFS

```
hdfs dfs -put data /user/ambari-qa/
```

Insert this into `bin/gremlin.sh` near the bottom before the last `exec $JAVA` line

```
JAVA_OPTIONS="$JAVA_OPTIONS -Dhdp.version=2.3.4.0-3485 -Djava.library.path=/usr/hdp/2.3.4.0-3485/hadoop/lib/native"
```

Install and activate the HadoopGraph and GraphComputer plugins. Make sure the TinkerPop versions match!

```
./bin/gremlin.sh

:set max-iteration 10
:install org.apache.tinkerpop hadoop-gremlin 3.1.0-incubating
:install org.apache.tinkerpop giraph-gremlin 3.1.0-incubating
:install org.apache.tinkerpop spark-gremlin 3.1.0-incubating
:q

./bin/gremlin.sh

:plugin use tinkerpop.hadoop
:plugin use tinkerpop.giraph
:plugin use tinkerpop.spark
:q
```
