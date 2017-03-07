#Bash Script to transfer files from one bucket to another bucket

#!/bin/bash 

echo "Starting script to transfer files from one bucket in S3 to another bucket in S3"
echo "###############################################################################"

echo -e "\n"


if [ "$1" == "" ]; then
	echo "No arguments provided. Exiting"
	exit
fi

TransferDescriptor="$1"



if [ ! -f $TransferDescriptor ]; then
	echo "File does not exist. Exiting"
	exit
fi

if [ "$#" -ne 7 ];
then
	echo "Illegal number of arguments. The input format is ./pathtoTranscript.sh inputfile.txt 
	From_Bucket_Name From_Bucket_Access_Key From_Bucket_Secret_Key To_Bucket_Name To_Bucket_Access_Key To_Bucket_Secret_Key"
	exit
fi


# remove logs from previous runs

rm -f DestinationFailureLog.txt
rm -f BackupFailureLog.txt

#obtain the from credentials from command line

From_Bucket="$2"
From_Bucket_Access_Key="$3"
From_Bucket_Secret_Key="$4"

To_Bucket="$5"
To_Bucket_Access_Key="$6"
To_Bucket_Secret_Key="$7" 


#read the contents of the file and parse it

SOURCEFILES=()
DESTINATIONFILES=()


		
regex='(.*) >> (.*)'
while IFS= read -r line dest
do 
    [[ $line =~ $regex ]] || continue
    src=${BASH_REMATCH[1]}
    dest=${BASH_REMATCH[2]}

    if [[ -n $src ]]; then
        SOURCEFILES+=("$src")
    fi
    if [[ -n $dest ]]; then  
        DESTINATIONFILES+=("$dest")
    fi  
done < "$TransferDescriptor"		
		

	
# check if there are equal number of source and destination files


if [ "${#SOURCEFILES[*]}" -ne "${#DESTINATIONFILES[*]}" ]; then
	echo "The count of source and destination files are not equal.Exiting"
	exit
fi

# Append full path to all the filenames

for((i=0;i<${#SOURCEFILES[@]};i++));
do
SOURCEFILES[i]="s3://""${From_Bucket}/""${SOURCEFILES[i]}"
done

for((i=0;i<${#DESTINATIONFILES[@]};i++));
do
#DESTINATIONFILES[i]="s3://""${To_Bucket}/""${DESTINATIONFILES[i]}"
DESTINATIONFILES[i]="${DESTINATIONFILES[i]}" #path not appended to create backup
done

## sanity check

for((i=0;i<${#DESTINATIONFILES[@]};i++));
do
echo "The source file is ""${SOURCEFILES[i]}"" and the destination file is ""s3://""${To_Bucket}/""${DESTINATIONFILES[i]}"
done
 

#remove records with invalid source 


SOURCEFILESTBCHKD=()
SOURCEFILESCHKD=()
DESTINATIONFILESCHKD=()
DESTINATIONFILESTBCHKD=()


#SOURCEFILESTBCHKD=("${!1}")
#DESTINATIONFILESTBCHKD=("${!2}")

SOURCEFILESTBCHKD=("${SOURCEFILES[@]}")
DESTINATIONFILESTBCHKD=("${DESTINATIONFILES[@]}")

#echo "The number of sourcefilestobechecked is " "${#SOURCEFILESTBCHKD[@]}"

for (( i=0 ;i<${#SOURCEFILESTBCHKD[@]};i++));  
do
	#echo "the source input is " "${SOURCEFILESTBCHKD[i]}" "and the destination input is " "${DESTINATIONFILESTBCHKD[i]}"
	
	
	
	temp=$(AWS_ACCESS_KEY_ID="${From_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${From_Bucket_Secret_Key}" /usr/local/bin/aws s3 ls "${SOURCEFILESTBCHKD[i]}" | wc -l )
	  
	if [[ "$temp" -eq 0 ]];
		then
		echo "The file " "${SOURCEFILESTBCHKD[i]}" " does not exist,skipping transfer ""${SOURCEFILESTBCHKD[i]}" "to " "s3://""${To_Bucket}/""${DESTINATIONFILESTBCHKD[i]}" 
	else
		SOURCEFILESCHKD+=("${SOURCEFILESTBCHKD[i]}")
		DESTINATIONFILESCHKD+=("${DESTINATIONFILESTBCHKD[i]}")
    
	fi	
done		
	

#append the full path to source directory

FPSOURCEFILES=("${SOURCEFILESCHKD[@]}")

#append the full path to destination directory

FPDESTINATIONFILES=("${DESTINATIONFILESCHKD[@]}")

#perform the transfer for the 'from bucket' to local

NumFilesCopiedtoTemp=0

for (( i=0 ;i<${#FPSOURCEFILES[@]};i++));  
do
	DIR=$(dirname "${FPSOURCEFILES[i]}")
	mkdir -p "/tmp/BashPlayArea2/""${DIR}"
	NumFilesCopiedtoTemp=$((NumFilesCopiedtoTemp+1))
	
	#echo "echoing aws s3 cp ""${FPSOURCEFILES[i]}" "/tmp/BashPlayArea2/""${FPSOURCEFILES[i]}"
	
	#aws s3 cp "${FPSOURCEFILES[i]}" "/tmp/BashPlayArea2/""${SOURCEFILES1[i]}" --profile From_Bucket_Cdn
	AWS_ACCESS_KEY_ID="${From_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${From_Bucket_Secret_Key}"	/usr/local/bin/aws s3 cp "${FPSOURCEFILES[i]}" "/tmp/BashPlayArea2/""${SOURCEFILES[i]}" 
	
done	

#perform the transfer for 'local' to 'to bucket'



for (( i=0 ;i<${#FPDESTINATIONFILES[@]};i++));  
do
	
	AWS_ACCESS_KEY_ID="${To_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${To_Bucket_Secret_Key}" /usr/local/bin/aws s3 cp "/tmp/BashPlayArea2/""${FPSOURCEFILES[i]}" "s3://""${To_Bucket}/""${FPDESTINATIONFILES[i]}" 
done	

#transfer from local to 'backup' at destination  
   

for (( i=0 ;i<${#FPDESTINATIONFILES[@]};i++));  
do
	
	AWS_ACCESS_KEY_ID="${To_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${To_Bucket_Secret_Key}" /usr/local/bin/aws s3 cp "/tmp/BashPlayArea2/""${FPSOURCEFILES[i]}" "s3://""${To_Bucket}/""$(date +'%Y_%m_%d')/""${FPDESTINATIONFILES[i]}"
	
done


###checks


#check the number of files in the source directory 

NUMSOURCEFIELES=0

for (( i=0 ;i<${#FPSOURCEFILES[@]};i++));  
do
	
	#AWS_ACCESS_KEY_ID="${To_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${To_Bucket_Secret_Key}" aws s3 cp "/tmp/BashPlayArea2/""${FPSOURCEFILES[i]}" "s3://""${To_Bucket}/""$(date +'%Y_%m_%d')/""${FPDESTINATIONFILES[i]}"
	
	temp=$(AWS_ACCESS_KEY_ID="${From_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${From_Bucket_Secret_Key}" /usr/local/bin/aws s3 ls "${FPSOURCEFILES[i]}" | wc -l )
	if [[ "$temp" -gt 0 ]]; 
	then
    NUMSOURCEFILES=$((NUMSOURCEFILES+1))
	fi
done

#check the number of files in the destination directory 

NUMDESTINATIONFILES=0

for (( i=0 ;i<${#FPDESTINATIONFILES[@]};i++));  
do
	
	#AWS_ACCESS_KEY_ID="${To_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${To_Bucket_Secret_Key}" aws s3 cp "/tmp/BashPlayArea2/""${FPSOURCEFILES[i]}" "s3://""${To_Bucket}/""$(date +'%Y_%m_%d')/""${FPDESTINATIONFILES[i]}"
	
	temp=$(AWS_ACCESS_KEY_ID="${To_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${To_Bucket_Secret_Key}" /usr/local/bin/aws s3 ls "s3://""${To_Bucket}/""${FPDESTINATIONFILES[i]}"  | wc -l )
	if [[ "$temp" -gt 0 ]]; 
	then
    NUMDESTINATIONFILES=$((NUMDESTINATIONFILES+1))
	fi
done

#check the number of files in backup directory

NUMBACKUPFILES=0

for (( i=0 ;i<${#NUMBACKUPFILES[@]};i++));  
do
	
	#AWS_ACCESS_KEY_ID="${To_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${To_Bucket_Secret_Key}" aws s3 cp "/tmp/BashPlayArea2/""${FPSOURCEFILES[i]}" "s3://""${To_Bucket}/""$(date +'%Y_%m_%d')/""${FPDESTINATIONFILES[i]}"
	temp=$(AWS_ACCESS_KEY_ID="${To_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${To_Bucket_Secret_Key}" /usr/local/bin/aws s3 ls "s3://""${To_Bucket}/""$(date +'%Y_%m_%d')/""${FPDESTINATIONFILES[i]}" | wc -l )
	if [[ "$temp" -gt 0 ]]; 
	then
    NUMBACKUPFILES=$((NUMBACKUPFILES+1))
	fi
done

#check if the number of source files is equal to the number of destination files






if [ "${NUMSOURCEFILES}" -ne "${NUMDESTINATIONFILES}" ];
then
	for (( i=0 ;i<${#FPDESTINATIONFILES[@]};i++));
	do
    # log errors where the source file is present but the destination file is not present
		temp1=$(AWS_ACCESS_KEY_ID="${To_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${To_Bucket_Secret_Key}" /usr/local/bin/aws s3 ls "s3://""${To_Bucket}/""${FPDESTINATIONFILES[i]}"  | wc -l )
	    if [[ "$temp1" -eq 0 ]];
		then
		 	echo "The file " "${FPDESTINATIONFILES[i]}" "at the destination directory does not exist" >> DestinationFailureLog.txt
    	fi
    	
    	temp1=$(AWS_ACCESS_KEY_ID="${To_Bucket_Access_Key}" AWS_SECRET_ACCESS_KEY="${To_Bucket_Secret_Key}" /usr/local/bin/aws s3 ls "s3://""${To_Bucket}/""$(date +'%Y_%m_%d')/""${FPDESTINATIONFILES[i]}" | wc -l )
    	
		if [["$temp2" -eq 0 ]];  
			then
			echo "The file ""s3://""${To_Bucket}/""$(date +'%Y_%m_%d')/""${FPDESTINATIONFILES[i]}"" at the backup directory does not exist" >> BackupFailureLog.txt
    	fi
    done	
fi
      
#remove the local directory

rm -r /tmp/BashPlayArea2
         
echo "Transfer Summary"
echo "================"

if [ "${NUMSOURCEFILES}" -eq "${NUMDESTINATIONFILES}" ];
then
echo "TRANSFER SUCCESSFUL"
echo "Number of files copied from " "${From_Bucket}"":   to " "${To_Bucket}" " is " "${NUMDESTINATIONFILES}"    
else
echo "TRANSFER UNSUCCESSFUL"
echo "Check DestinationFailureLog.txt for unsuccessful transfer of destination files"
echo "Check BackupFailureLog.txt for unsuccessful transfer of backup files" 
fi


