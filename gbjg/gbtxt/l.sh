#!/bin/bash
USER=$1
PASS=$2
database=$3
durl="http://quote.tool.hexun.com/hqzx/quote.aspx?type=2&market=0&sorttype=3&updown=up&page=1&count=5000"
url="http://stockdata.stock.hexun.com"
lurl="/2008/accountlist.aspx?ggid=10000004&appcode=TOP10_CURRSTOCKHOLDER_DETAIL_TAB&url=/2008/sdltgd.aspx?stockid="
#更新股票代码/名称
dname() {
curl -s "$durl" |iconv -f gbk -t utf-8 |sed -e '/dataArr.*/d' -e 's/^\[\([^,]\{8\},[^,]\{3,9\}\),.*$/\1/g' -e 's/ //g' | while read LINE
do
read dm name < <(echo $LINE |awk -F , '{print $1,$2}')
mysql -u $USER -p$PASS $database <<EOF
	create table if not exists list_gp (	
	id varchar(20),
	name varchar(20),
	uping varchar(20),
	UNIQUE KEY id (id),
	UNIQUE KEY name (name)
 	);
	INSERT INTO list_gp VALUES ($dm,$name,"n") ON DUPLICATE KEY UPDATE name=$name;
EOF
done
echo "更新股票代码/名称成功"
}
#更新季度表
jd() {
idt=`mysql -u $USER -p$PASS -N $database <<EOF
	select id from list_gp 
	where uping="n";
EOF`
echo "$idt" | while read id
do
curl -s "$url$lurl$id" |iconv -f gbk -t utf-8 |grep tb10 | sed 's/[\t ]//g' |sed 's/<\/a>/\n/g' |sed -e "s/^<.*ahref='\(.*\)amp;\(.*\)'target.*>\(.*$\)/\1\2,\3/g" -e '/nbsp/d' -e 's/[第年前季期]//g' -e 'y/中度/24/' |sort | while read LINE
do
read jurl jd < <(echo $LINE |awk -F , '{print $1,$2}')
ijd=`mysql -u $USER -p$PASS -N $database <<EOF
	create table if not exists list_jd (
	id VARCHAR(20),
	jd VARCHAR(200),
	UNIQUE KEY id (id)
	);
	select jd from list_jd 
	where id=$id;
EOF`
if [[ `echo $ijd |awk -F , '{print $1}'` < $jd ]];then
hgb=`curl -s "$url$jurl" |iconv -f gbk -t utf-8 |grep tishi | sed 's/[\t]//g'`
if [ -n "$hgb" ];then
lgd=`echo $hgb | sed 's/<\/tr>/\n/g' |grep tishi | sed 's/,//g' | sed 's/"/\\\"/g' | sed "s/^.*>\([^<]\+\)<.*>\([^<]\+\)<.*>\([^<]\+\)<.*>\([^<]\+\)<.*>\([^<]\+\)<.*$/(\"${id}\",\"\1\",\2,\"\3\",\"\4\",\"\5\"),/g" |sed '$s/,$//'`
mysql -u $USER -p$PASS $database <<EOF
	create table if not exists list_jd (
	id VARCHAR(20),
	jd VARCHAR(200),
	UNIQUE KEY id (id)
	);
	create table if not exists jd$jd (	
	id VARCHAR(20),
	name VARCHAR(100),
	gs INT,
	bl VARCHAR(100),
	xz VARCHAR(100),
	bh VARCHAR(100),
	INDEX id (id),
	INDEX name (name)
 	);
	delete from jd$jd where id=$id;
	INSERT INTO jd$jd VALUES $lgd;
	INSERT INTO list_jd VALUES ("$id","$jd") ON DUPLICATE KEY UPDATE jd=concat("$jd,",jd);
	update list_gp set uping="up" where id=$id;
EOF
echo "$id:$jd更新成功！"
else
mysql -u $USER -p$PASS $database <<EOF
	update list_gp set uping="nd" where id=$id;
EOF
echo "$id:$jd无数据！"
fi
else
mysql -u $USER -p$PASS $database <<EOF
	update list_gp set uping="up" where id=$id;
EOF
echo "$id无需更新！"
fi
done
done
}
usage() {
echo "	dm 更新股票代码/名称"
echo "	jd 更新十大流通股东"
}
case "$1" in
	dm)
		( dname && echo "更新成功!" ) || echo "error."
		exit 0
		;;

	jd)
		( jd && echo "更新成功!" ) || echo "error."
		exit 0
		;;
	all)
		( dname && jd && echo "更新成功!" ) || echo "error."
		exit 0
		;;
	*) usage
		exit 1
		;;
esac
