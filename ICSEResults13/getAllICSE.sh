#!/bin/bash
# Instructions to run
#
# ./getAllICSE.sh 4670 4700
#
# This fetches all the results between the first and second argument
#
# Minimum Lower Limit = 4001
# Maximum Upper Limit = 5568
#
# Headers: 
# echo 'Name,Roll No,School,Subject,Marks,Subject,Marks,Subject,Marks,Subject,Marks,Subject,Marks,Subject,Marks,Overall Average,Best of 4 Subjects,English + Best of 3 Subjects'

if [ "$#" -ne "2" ]
then
echo "Please input the initial and final school code as the argument when running this script" 
exit
fi
if ! [[ "$1" =~ ^[0-9]+$ ]]
then
echo "Initial school code supplied is not a valid number"
exit
fi
if ! [[ "$2" =~ ^[0-9]+$ ]]
then
echo "Final school code supplied is not a valid number"
exit
fi
if [ "${#1}" -ne "4" ]
then
echo "Initial school code supplied is not of valid length. Please enter a school code of 4 digits"
exit
fi
if [ "${#2}" -ne "4" ]
then
echo "Final school code supplied is not of valid length. Please enter a school code of 4 digits"
exit
fi
let diff=$2-$1
if [ "$diff" -lt "0" ]
then
	echo "Difference is negative, please enter lower school ID first" 
	exit
fi

fail_limit=3
for schoolcode in $(seq $1 $2)
do
for serverno in $(seq 1 4)
do
	echo 'Fetching results on server '${serverno}'...';
	serverurl='http://www.cisce.ndtv.com/web/10th/10-'${serverno}
	let badcount=0
	filename=''
	let studentno=0
	while true;
	do
	let studentno++
	idlen=${#studentno}
	let idlen=3-$idlen
	if [ "$idlen" -ne "0" ]
	then
		zeroes=`yes "0" | head -n $idlen | tr -d '\n'`
		studentid=${zeroes}${studentno}
	else
		studentid=${studentno}
	fi
	url=${serverurl}'/'${schoolcode}${studentid}'.html'
	echo 'Fetching results for T/'${schoolcode}'/'${studentid}
	refined=`curl -silent $url | grep -Eo '>[^<]{1,}<' | tr -d '*' | tr -d '>' | tr -d '<' | tr '\n' ' ' | sed -E 's/ {1,}/ /g'`
	id=`echo $refined | grep -Eo 'T/[[:digit:]]{4}/[[:digit:]]{3}'`
	schoolname=`echo $refined | grep -Eo 'School .{1,}Date' | sed -E 's/School //g' | sed -E 's/ Date//g' | tr ',' ' '`
	if [ -z "$filename" -a -n "$schoolname" ]
	then
		reducedschoolname=`echo $schoolname | tr -d "s/\.\\/:\*?\"<>|\'" | tr [:upper:] [:lower:]`
		reducedschoolname=`echo $reducedschoolname |  awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' | tr -d ' '`
		filename='ICSE-Results'${schoolcode}${reducedschoolname}'.csv'
		echo
		echo 'Creating file '${filename}' to store results...'
		echo
		rm -f $filename
		touch $filename
	fi
	dob=`echo $refined | grep -Eo 'Birth .{1,}Subjects' | sed -E 's/Birth //g' | sed -E 's/ Subjects//g'`
	name=`echo $refined | grep -Eo 'Name .{1,}School' | sed -E 's/Name //g' | sed -E 's/ School//g'`
	marks=`echo $refined | grep -Eo '[A-Z]{3} [[:digit:]]{1,3}' | sed -E 's/(ODE|RUP|TOR) [[:digit:]]{1,3}//g'`
	engmarks=`echo $marks | grep -Eo 'ENG [[:digit:]]{1,3}' | sed -E 's/ENG //g'`
	bestfive=`echo $marks | grep -Eo '[[:digit:]]{1,3}' | sort -n | tail -5 | awk '{sum+=$1; } END { print sum/5 }'`
	bestfour=`echo $marks | sed -E 's/ENG [[:digit:]]{1,3}//g' | grep -Eo '[[:digit:]]{1,3}' | sort -n | tail -4 | awk '{sum+=$1;} END { print sum }'`
	let engandbestfourtot=$(( bestfour + engmarks))
	engandbestfour=`echo $engandbestfourtot | awk '{ print $1/5 } '`
	total=`echo $marks | grep -Eo '[[:digit:]]{1,3}' | awk '{sum+=$1; count+=1;} END { if (count>0) { print sum/count }}'`
	marktxt=`echo $marks | sed -E 's/ /,/g' | tr '\n' ','`
	count=`echo $marks | grep -Eo '[[:digit:]]{1,3}' | wc -l`
	if [ "$count" -eq "0" ]
	then
		let badcount++
		if [ "$badcount" -eq "$fail_limit" ]
		then
			break
		fi 
	else
		let badcount=0
		finalrow=${name}','${id}','${schoolname}','${dob}','${marktxt}
		commacount=`echo $finalrow | grep -o ',' | wc -l`
		let remainder=$((16-commacount))
		if [ "$remainder" -ne "0" ]
		then
			commas=`yes "," | head -n $remainder | tr -d '\n'`
			finalrow=${finalrow}${commas}
		fi
		finalrow=${finalrow}${total}','${bestfive}','${engandbestfour}
		echo $finalrow
		echo $finalrow >> $filename;
	fi
	echo
	done
done
done
