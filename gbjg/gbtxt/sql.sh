#awk -F ' {3,8}' '{print $2",\""$3"\","$4","$5","$6}'
USER="root"
PASS="loveover"
database="gbjg"
mysql -u $USER -p$PASS $database <<EOF
	create table if not exists list_jd (	
	tab VARCHAR(20),
	jd VARCHAR(20)
 	);
EOF
ls */* | sed 's/[ ]/\n/g' > ls.log
while read line;
do
data=$line
#echo $data
i=1
da=""
while read line;
do
 if [ $i = 1 ];then
 query=`echo "$line" | sed 's/[\t ]//g'`
 else
 query=`echo "$line" | awk -F ' {3,8}' '{print $1"|"$2"|"$3"|"$4"|"$5}'`
 fi
i=$(($i+1))
case $query in
简称*代码*)
name=`echo $query | awk -F '[简称代码：]' '{print $4"\",\""$7}'`
echo $name
;;
1?年*\|\|\|\|)
if [[ $da != ${query%%|*} ]];then
da=${query%%|*} #季度
day=`echo $da | sed -e 's/前/第/' -e 's/中期/第2季/' -e 's/年度/第4季/'`
table=`echo $day | sed 'y/年第季/ndj/'`
echo $table
mysql -u $USER -p$PASS $database <<EOF
	create table if not exists $table (	
	jc VARCHAR(20),
	dm VARCHAR(10),
	name VARCHAR(255),
	gs VARCHAR(20),
	bl VARCHAR(20),
	xz VARCHAR(20),
	bh VARCHAR(20)
 	);
	update 
EOF
fi
;;
合计*\|\|\|\|)
#echo 3$query
;;
*\|\|*)
#echo 4$query
;;
股东名称\|*)
#echo $query
;;
*)
query=`echo $query | awk -F '|' '{print $1"\",\""$2"\",\""$3"\",\""$4"\",\""$5}'`
mysql -u $USER -p$PASS $database <<EOF
	INSERT INTO $table VALUES("$name","$query");
EOF
#echo $day,$id,$name,$query #股东
;;
esac
done < $data
done < ls.log
