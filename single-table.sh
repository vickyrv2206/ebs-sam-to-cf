#!/bin/bash
tables_list=$(aws dynamodb list-tables)
date
# Splitting prod and uat tables into separate array
echo -e "\n\nSplitting prod and uat tables into separate array"
table_flag=0
src_env="prod"
dest_env="split"
src_table_count=0
dest_table_count=0
table=$(echo $tables_list | jq .TableNames[$table_flag])
while [ "$table" != "null" ]
do

    if [[ $table == *"ebs-telxcel-$src_env-stack"* ]]; then
        src_table[src_table_count]="${table//\"}"
        src_table_count=$(( src_table_count+1 ))
    elif [[ $table == *"ebs-telxcel-$dest_env-stack"* ]]; then
        dest_table[dest_table_count]="${table//\"}"
        dest_table_count=$(( dest_table_count+1 ))    
    fi
    table_flag=$(( table_flag+1 ))
    table=$(echo $tables_list | jq .TableNames[$table_flag])
done

# echo ${dest_table[@]}

echo -e "Source and dest tables are splitted into respective arrays"
# cleaning uat tables

# copying tables content from prod to uat...
echo -e "\n\ncopying tables content from src to destination..."
table_flag=0
if [ $src_table_count == $dest_table_count ]; then
    echo -e "\nTables count are equal for src and dest"
    while (( $table_flag < $src_table_count ))
    do    
        IFS='-' read -ra src <<< "${src_table[$table_flag]}"
        IFS='-' read -ra dest <<< "${dest_table[$table_flag]}"
        if [ ${src[4]} == ${dest[4]} -a ${src[4]} == "$1" ]; then
            echo -e "\n\ncopy ${src_table[$table_flag]} table contents to ${dest_table[$table_flag]} table"
            scan=$(aws dynamodb scan --table-name ${src_table[$table_flag]} --max-items 500)
            next_token=$( echo $scan | jq .NextToken)
            echo -e "scaning ${src_table[$table_flag]} table one set completed..."
            set_count=0
            while [ "$next_token" != "null" ]
            do
                i=0
                item=$(echo $scan | jq .Items[$i])
                while [ "$item" != "null" ]
                do
                    aws dynamodb put-item --table-name ${dest_table[$table_flag]} --item "$item"
                    set_count=$(( set_count+1 ))
                    echo -ne "Copied item: "$set_count '\r'
                    i=$(( i+1 ))
                    item=$(echo $scan | jq .Items[$i])
                done
                echo -e "Wrote ${src_table[$table_flag]} table one set"
                scan=$(aws dynamodb scan --table-name ${src_table[$table_flag]} --max-items 500 --starting-token $next_token)
                next_token=$( echo $scan | jq .NextToken)  
                echo -e "scaning ${src_table[$table_flag]} table another set completed..."

            done
            i=0
            item=$(echo $scan | jq .Items[$i])
            while [ "$item" != "null" ]
            do
                aws dynamodb put-item --table-name ${dest_table[$table_flag]} --item "$item"
                set_count=$(( set_count+1 ))
                echo -ne "Copied item: "$set_count '\r'
                i=$(( i+1 ))
                item=$(echo $scan | jq .Items[$i])
            done
            echo -e "Wrote ${src_table[$table_flag]} table one set"
            echo -e "copied table contents from ${src_table[$table_flag]} table to ${dest_table[$table_flag]} table"
            echo -e "Total items are: $set_count\n\n"
        else
            echo "skipping ${src_table[$table_flag]}"
            # echo "${src_table[$table_flag]}   ${dest_table[$table_flag]}"
            # echo "Tables sequence not matching"
            # exit 0
        fi
        table_flag=$(( table_flag+1 ))    
    done
    date
else
    echo -e "\n\n Tables are not equal for prod and uat \n\n"
    exit 0
fi

# copying contents in s3 bucket
# aws s3 sync s3://ebs-telxcel-prod-stack-zwibbler-files s3://ebs-telxcel-uat-stack-zwibbler-files
# aws s3 sync s3://ebs-telxcel-prod-stack-activity-images s3://
