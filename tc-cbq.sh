#INGOING traffic (gateway)
IN=eth1
start(){
	/sbin/tc qdisc del dev $IN root 2>/dev/null
	/sbin/tc qdisc add dev $IN root handle 1: cbq bandwidth 3Mbit avpkt 1000 cell 8 mpu 64
	#将一个cbq队列绑定到网络物理设备$IN上，其编号为1:0；网络物理设备$IN的实际带宽为3 Mbit，包的平均大小为1000字节；包间隔发送单元的大小为8字节，最小传输包大小为64字节。
	
	#1)创建根分类1:1；分配带宽为3Mbit，优先级别为8。
	/sbin/tc class add dev $IN parent 1:0 classid 1:1 cbq bandwidth 3Mbit rate 3Mbit maxburst 20 allot 1514 prio 8 avpkt 1000 cell 8 weight 500Kbit
	#该队列的最大可用带宽为3Mbit，实际分配的带宽为3Mbit，可接收冲突的发送最长包数目为20字节；最大传输单元加MAC头的大小为1514字节，优先级别为8，包的平均大小为1000字节，包间隔发送单元的大小为8字节，相应于实际带宽的加权速率为500Kbit。
	
	#2）创建分类1:2，其父分类为1:1，分配带宽为2Mbit，优先级别为1。
	/sbin/tc class add dev $IN parent 1:1 classid 1:2 cbq bandwidth 3Mbit rate 1Mbit maxburst 20 allot 1514 prio 1 avpkt 1000 cell 8 weight 200Kbit split 1:0 #bounded
	#该队列的最大可用带宽为3Mbit，实际分配的带宽为 2Mbit，可接收冲突的发送最长包数目为20字节；最大传输单元加MAC头的大小为1514字节，优先级别为1，包的平均大小为1000字节，包间隔发送单元的大小为8字节，相应于实际带宽的加权速率为800Kbit，分类的分离点为1:0，且不可借用未使用带宽。
	#3）创建分类1:3，其父分类为1:1，分配带宽为1500Kbit，优先级别为2。
	/sbin/tc class add dev $IN parent 1:1 classid 1:3 cbq bandwidth 3Mbit rate 1000Kbit maxburst 20 allot 1514 prio 2 avpkt 1000 cell 8 weight 100Kbit split 1:0
	#该队列的最大可用带宽为3Mbit，实际分配的带宽为 1500Kbit，可接收冲突的发送最长包数目为20字节；最大传输单元加MAC头的大小为1514字节，优先级别为2，包的平均大小为1000字节，包间隔发送单元的大小为8字节，相应于实际带宽的加权速率为100Kbit，分类的分离点为1:0。
	#4）创建分类1:4，其父分类为1:1，分配带宽为1000Kbit，优先级别为6。
	/sbin/tc class add dev $IN parent 1:1 classid 1:4 cbq bandwidth 3Mbit rate 1000Kbit maxburst 20 allot 1514 prio 6 avpkt 1000 cell 8 weight 100Kbit split 1:0
	#该队列的最大可用带宽为3Mbit，实际分配的带宽为1000Kbit，可接收冲突的发送最长包数目为20字节；最大传输单元加MAC头的大小为1514字节，优先级别为6，包的平均大小为1000字节，包间隔发送单元的大小为8字节，相应于实际带宽的加权速率为100Kbit，分类的分离点为1:0。

	#1） 应用路由分类器到cbq队列的根，父分类编号为1:0；过滤协议为ip，优先级别为100，过滤器为基于路由表。
	/sbin/tc filter add dev $IN parent 1:0 protocol ip prio 100 route
	#2） 建立路由映射分类1:2, 1:3, 1:4
	/sbin/tc filter add dev $IN parent 1:0 protocol ip prio 100 route to 2 flowid 1:2
	/sbin/tc filter add dev $IN parent 1:0 protocol ip prio 100 route to 3 flowid 1:3
	/sbin/tc filter add dev $IN parent 1:0 protocol ip prio 100 route to 4 flowid 1:4

	/sbin/ip route del 192.168.0.0/24 dev eth1  proto kernel  scope link  src 192.168.0.1
	#1） 发往主机192.168.1.24的数据包通过分类2转发(分类2的速率2Mbit)
	/sbin/ip route add 192.168.0.2 dev $IN via 192.168.0.1 realm 4

	#2） 发往主机192.168.1.30的数据包通过分类3转发(分类3的速率1500Kbit)
	/sbin/ip route add 192.168.0.3 dev $IN via 192.168.0.1 realm 2
	/sbin/ip route add 192.168.0.4 dev $IN via 192.168.0.1 realm 2
	/sbin/ip route add 192.168.0.5 dev $IN via 192.168.0.1 realm 2
	#3）发往子网192.168.1.0/24的数据包通过分类4转发(分类4的速率1000Kbit)
	/sbin/ip route add 192.168.0.0/24 dev $IN via 192.168.0.1 realm 3

	#注：一般对于流量控制器所直接连接的网段建议使用IP主机地址流量控制限制，不要使用子网流量控制限制。如一定需要对直连子网使用子网流量控制限制，则在建立该子网的路由映射前，需将原先由系统建立的路由删除，才可完成相应步骤。
}
stop(){
	
	echo -n "(Delete all qdisc......)"
	/sbin/ip route del 192.168.0.0/24 dev $IN via 192.168.0.1 realm 3
	/sbin/ip route add 192.168.0.0/24 dev eth1  proto kernel  scope link  src 192.168.0.1
	/sbin/ip route del 192.168.0.2 dev $IN via 192.168.0.1 realm 4
	#2） 发往主机192.168.1.30的数据包通过分类3转发(分类3的速率1500Kbit)
	/sbin/ip route del 192.168.0.3 dev $IN via 192.168.0.1 realm 2
	/sbin/ip route del 192.168.0.4 dev $IN via 192.168.0.1 realm 2
	/sbin/ip route del 192.168.0.5 dev $IN via 192.168.0.1 realm 2
	#3）发往子网192.168.1.0/24的数据包通过分类4转发(分类4的速率1000Kbit)
	(/sbin/tc qdisc del dev $IN root 2>/dev/null && echo "ok.Delete sucessfully!") || echo "error."
}
#show status
status() {
	echo "1.show qdisc $IN:----------------------------------------------"
	/sbin/tc -s qdisc show dev $IN
	echo "2.show class $IN:----------------------------------------------"
	N1=`/sbin/tc class show dev $IN | wc -l`
	if [ $N1 = 0 ];then
	    echo "NULL, OFF Limiting "
	else
	    /sbin/tc -s class show dev $IN
	    echo "It work"
	fi
	echo "3.show ip route :----------------------------------------------"
	ip route
}
#show help
usage() {
        echo "(usage): `basename $0` [start | stop | restart | status ]"
        echo "help:"
        echo "start -- TC Flow Control start"
        echo "stop -- TC Flow Control stop"
        echo "restart -- TC Flow Control restart"
        echo "status -- TC Show all TC Qdisc and class"
}
case "$1" in
	start)
		( start && echo "Flow Control! tc started!" ) || echo "error."
		exit 0
		;;

	stop)
		( stop && echo "Flow Control tc stopped!" ) || echo "error."
		exit 0
		;;
	restart)
		stop
		start
		echo "Flow Control restart"
		;;
	status)
		status
		;;

	*) usage
		exit 1
		;;
esac
