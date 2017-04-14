#!/bin/bash
x=(600 601 603 300 000 002 )
for ((j=0; j< ${#x[*]}; j++))
do
	if [ ! -x "${x[$j]}" ]; then 
		mkdir ${x[$j]}
	fi
	i=000
	while [ $i -le 999 ]
	do
		i1=$(printf "%03d" "$i")
#		echo ${x[$j]}$i1
		m=$(curl http://stockdata.stock.hexun.com/2009_sdltgd_${x[$j]}$i1.shtml)
		n=$(echo $m |grep -a add3)
		if [ -n "$n" ]
		then			
			echo $m |grep -a h3 | sed 's/<\/tr>/\n/g' | sed 's/<[^>]*>/ /g' > ./${x[$j]}/${x[$j]}$i1
			echo $n | sed 's/<\/tr>/\n/g' | sed 's/<[^>]*>/ /g' >> ./${x[$j]}/${x[$j]}$i1
		fi
		i=$(($i+1))
	done
done
