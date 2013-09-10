#!/bin/bash

help() {
	echo "

Usage: $0 HADOOP_HOME_PATH SLAVE_SERVER_LIST [START_STEP]
   ex: $0 /opt/hadoop hadoop02,hadoop03 
       $0 /opt/hadoop hadoop02,hadoop03 3

"
}

require_pkg() {
	echo "

Need '$1'. Install it by typing:
sudo yum install -y $1

"
}


#####################################
# check arguments
#####################################

START_STEP=1
if [ $# -eq 3 ]; then
	START_STEP=$3
elif [ $# -ne 2 ]; then
	help
	exit 1
fi

HADOOP_HOME="$1"
SLAVE_SERVERS="$2"
USER=`whoami`
HOSTNAME=`hostname`


case $START_STEP in

	1)

echo "
#####################################
# STEP: 1
#
# check installed wget, patch
# check jdk 6+
# check JAVA_HOME
#####################################
"

WGET_VER=$(wget --version 2>&1)
if [ $? -ne 0 ]; then
	require_pkg "wget"
	exit 1
fi

PATCH_VER=$(patch --version 2>&1)
if [ $? -ne 0 ]; then
	require_pkg "patch"
	exit 1
fi

JAVA_ORG_VER=$(java -version 2>&1)
if [ $? -ne 0 ]; then
	echo "Need jdk 6+"
	echo ""
	exit 1
fi

JAVA_VER=$(echo "$JAVA_ORG_VER" | sed 's/java version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q')
if [ ! "$JAVA_VER" -ge 16 ]; then
	echo "Need jdk 6+"
	echo ""
	exit 1
fi

if [ "$JAVA_HOME" == "" ]; then
	echo "Need set JAVA_HOME"
	echo ""
	exit 1
fi

echo "STEP: 1 -> OK"

	;&


	2)

echo "
#####################################
# STEP: 2
#
# check ssh login by authorized_keys
#####################################
"

cat <<EOF
Hadoop need to login by authorized key to slave nodes in ssh.
If, cannot login by authozied key, following procedure:

  ssh-keygen -t rsa
  for server in $HOSTNAME ${SLAVE_SERVERS//,/ }; do scp ~/.ssh/id_rsa.pub \$server:~/ && ssh \$server "if [ ! -e ~/.ssh ]; then mkdir -p ~/.ssh; fi; cat id_rsa.pub >> ~/.ssh/authorized_keys && chmod -R 700 ~/.ssh"; done

do you set ssh? [y/n]
EOF
read isSetSsh
if [ "$isSetSsh" == "y" ]; then
    exit 1
fi

echo "STEP: 2 -> OK"

	;&


	3)

echo "
#####################################
# STEP: 3
#
# install
#####################################
"

mkdir -p $HADOOP_HOME

PKG_HADOOP=hadoop-1.0.4.tar.gz
ORG_HADOOP=hadoop-1.0.4
wget http://archive.apache.org/dist/hadoop/core/hadoop-1.0.4/hadoop-1.0.4.tar.gz
tar xvfz $PKG_HADOOP
mv $ORG_HADOOP $HADOOP_HOME
ln -s $HADOOP_HOME/$ORG_HADOOP $HADOOP_HOME/hadoop
rm -rf $PKG_HADOOP

echo "STEP: 3 -> OK"

	;&


	4)

echo "
#####################################
# STEP: 4
#
# configuration backup & setting
#####################################
"

cd $HADOOP_HOME/hadoop/conf

cp core-site.xml core-site.xml.org
patch -p0 <<EOF
--- core-site.xml.org	2013-05-23 23:53:44.743495472 +0900
+++ core-site.xml	2013-05-23 23:59:15.108426820 +0900
@@ -4,5 +4,8 @@
 <!-- Put site-specific property overrides in this file. -->

 <configuration>
-
+	<property>
+		<name>fs.default.name</name>
+		<value>hdfs://${HOSTNAME}:9000</value>
+	</property>
 </configuration>
EOF

cp hadoop-env.sh hadoop-env.sh.org
patch -p0 <<EOF
--- hadoop-env.sh.org	2013-05-23 23:54:03.454575784 +0900
+++ hadoop-env.sh	2013-06-27 22:33:06.340893588 +0900
@@ -6,7 +6,7 @@
 # remote nodes.

 # The java implementation to use.  Required.
-# export JAVA_HOME=/usr/lib/j2sdk1.5-sun
+export JAVA_HOME=$JAVA_HOME

 # Extra Java CLASSPATH elements.  Optional.
 # export HADOOP_CLASSPATH=
EOF

cp hdfs-site.xml hdfs-site.xml.org
patch -p0 <<EOF
--- hdfs-site.xml.org	2013-05-24 00:01:54.330678973 +0900
+++ hdfs-site.xml	2013-05-24 00:10:16.502541079 +0900
@@ -4,5 +4,24 @@
 <!-- Put site-specific property overrides in this file. -->

 <configuration>
-
+	<property>
+		<name>dfs.replication</name>
+		<value>3</value>
+		<description>The actual number of replications can be specified when the file is created.
+		</description>
+	</property>
+	<property>
+		<name>dfs.datanode.max.xcievers</name>
+		<value>4096</value>
+	</property>
+	<property>
+		<name>tasktracker.http.threads</name>
+		<value>400</value>
+		<final>true</final>
+	</property>
+	<property>
+		<name>dfs.block.size</name>
+		<value>134217728</value>
+		<final>true</final>
+	</property>
 </configuration>
EOF

cp mapred-site.xml mapred-site.xml.org
patch -p0 <<EOF
--- mapred-site.xml.org	2013-05-24 00:13:14.547420991 +0900
+++ mapred-site.xml	2013-05-24 23:50:11.022801847 +0900
@@ -4,5 +4,28 @@
 <!-- Put site-specific property overrides in this file. -->

 <configuration>
-
+	<property>
+		<name>mapred.job.tracker</name>
+		<value>${HOSTNAME}:9001</value>
+		<description>The host and port that the MapReduce job tracker runs at.  </description>
+	</property>
+	<property>
+		<name>mapred.tasktracker.map.tasks.maximum</name>
+		<value>7</value>
+		<final>true</final>
+	</property>
+	<property>
+		<name>mapred.tasktracker.reduce.tasks.maximum</name>
+		<value>7</value>
+		<final>true</final>
+	</property>
+	<property>
+		<name>mapred.task.timeout</name>
+		<value>30000</value>
+		<final>true</final>
+	</property>
+	<property>
+		<name>mapred.child.java.opts</name>
+		<value>-Xmx400m</value>
+	</property>
 </configuration>
EOF

cp masters masters.org
echo $HOSTNAME > masters

cp slaves slaves.org
rm slaves
for server in ${SLAVE_SERVERS//,/ }; do
    echo $server >> slaves
done

echo "STEP: 4 -> OK"

	;&


	5)

echo "
#####################################
# STEP: 5
#
# distribute to slave nodes
#####################################
"

for server in ${SLAVE_SERVERS//,/ }; do
    ssh $server "mkdir -p $HADOOP_HOME"

    if [ $? -eq 0 ]; then
    	scp -r $HADOOP_HOME/$ORG_HADOOP $server:$HADOOP_HOME/
    	ssh $server "ln -s $HADOOP_HOME/$ORG_HADOOP $HADOOP_HOME/hadoop"
    fi
done

echo "STEP: 5 -> OK"

	;&


	6)

echo "
#####################################
# STEP: 6
#
# create start/stop shell:
#   $HADOOP_HOME/hadoop/bin/hadoop.sh
#####################################
"

cat > $HADOOP_HOME/hadoop/bin/hadoop.sh<<EOF
#!/bin/bash

# Source function library.
#. /lib/lsb/init-functions

HADOOP_HOME=$HADOOP_HOME/hadoop

RETVAL=0

USER=$USER
WHOAMI=\$(whoami)

start() {
	if [ "\${WHOAMI}" == "\${USER}" ]; then
		\${HADOOP_HOME}/bin/start-all.sh
	else
		su \$USER -c "exec \${HADOOP_HOME}/bin/start-all.sh"
	fi
	
	RETVAL=\$?
}

stop() {
	if [ "\${WHOAMI}" == "\${USER}" ]; then
		\${HADOOP_HOME}/bin/stop-all.sh
	else
		su \$USER -c "exec \${HADOOP_HOME}/bin/stop-all.sh"
	fi
	
	RETVAL=\$?
}

# See how we were called.
case "\$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		stop
		start
		;;
	*)
		echo $"Usage: \$0 {start|stop|restart}"
		RETVAL=3
esac

exit \$RETVAL
EOF
chmod 755 $HADOOP_HOME/hadoop/bin/hadoop.sh

echo "STEP: 6 -> OK"

	;&


	*)

cat <<EOF


Install Info

    Installed Path:
        $HADOOP_HOME/hadoop

    Modified files:
        $HADOOP_HOME/hadoop/conf/core-site.xml
        $HADOOP_HOME/hadoop/conf/hadoop-env.sh
        $HADOOP_HOME/hadoop/conf/hdfs-site.xml
        $HADOOP_HOME/hadoop/conf/mapred-site.xml
        $HADOOP_HOME/hadoop/conf/masters
        $HADOOP_HOME/hadoop/conf/slaves

    Created files:
        $HADOOP_HOME/hadoop/bin/hadoop.sh


Do Next Step

    1. Initialize HDFS
        $HADOOP_HOME/hadoop/bin/hadoop namenode -format

    2. Modify Firewall
    2.1 Add following lines in '/etc/sysconfig/iptables' of all hadoop nodes:

# hadoop
-A INPUT -m state --state NEW -m tcp -p tcp --dport 9000 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 9001 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 50010 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 50020 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 50030 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 50060 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 50070 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 50075 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 50090 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 50105 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 50470 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 50475 -j ACCEPT

    2.2 restart iptables of all hadoop nodes
       sudo service iptables restart

    3. Modify limit 
    3.1 Add following lines in '/etc/security/limits.conf' of all hadoop nodes:

* - nofile 32768
* soft nproc 32000
* hard nproc 32000

    3.2 Add following lines in '/etc/pam.d/common-session' of all hadoop nodes:

session required  pam_limits.so

    4. Start Server
        $HADOOP_HOME/hadoop/bin/hadoop.sh start

EOF
	;;

esac
