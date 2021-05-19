#! /bin/bash
LIST_OF_INSTANCES="/mnt/backup00/list_of_apollo_instances.txt"
while read NAME; do
echo $NAME
tmp=${NAME:7:3}
INSTANCE_NUM=$((10#$tmp))
INSTANCE_MOD7=$((10#$tmp%7))
# Can get full hostname from ~backup_user/.ssh/config
REMOTE_HOST=$NAME".genome.edu.au"
DAY=$(date +"%Y%m%d")
DAY_NUM_OF_WEEK=$(date +%w)
BACKUP_DIR="/mnt/backup00/$NAME"
ARCHIVE_DIR=$BACKUP_DIR"_archive"
LOGFILE_DIR="/mnt/backup00/logs"
LOGFILE=$LOGFILE_DIR"/"$NAME".log"

echo $NAME, $INSTANCE_NUM, $INSTANCE_MOD7, $REMOTE_HOST
echo $DAY, $DAY_NUM_OF_WEEK
echo $BACKUP_DIR, $ARCHIVE_DIR, $LOGFILE 

if [ ! -d $BACKUP_DIR ]; then
          mkdir $BACKUP_DIR;
   fi
if [ ! -d $ARCHIVE_DIR ]; then
          mkdir $ARCHIVE_DIR;
   fi

   echo "rsyncing data ..."
#/usr/bin/rsync -e ssh -avrL --numeric-ids --rsync-path="sudo rsync" backup_user@$REMOTE_HOST:/home/ $BACKUP_DIR --log-file=$LOGFILE
echo "completed"
echo "getting SQL ..."
#ssh $REMOTE_HOST "pg_dump apollo-production -U backup_user" > $BACKUP_DIR/apollo-production.sql 
#pg_dump apollo-production -h apollo-002.genome.edu.au -U backup_user > apollo-002_2020_11_09.sql
if [ $INSTANCE_NUM -lt 7 ]
   then 
	 echo $INSTANCE_NUM, " Ordinary pg_dump"
#   	 pg_dump apollo-production -h $REMOTE_HOST -U backup_user > $BACKUP_DIR"/"$NAME"_"$DAY".sql"
   else  
	 echo $INSTANCE_NUM, " Docker pg_dump"  
         SSH_CMD="$REMOTE_HOST"" docker exec -i postgres10container pg_dump -U backup_user apollo-production > ~backup_user/apollo-007-prod_20210310_test1.sql"
         echo $SSH_CMD
	 ssh $SSH_CMD

   fi
# docker exec -i postgres10container pg_dump -U backup_user apollo-production > ~backup_user/apollo-007-prod_20210310.sql
#SSH_CMD="$REMOTE_HOST"" pg_dump apollo-production -U backup_user" 
#echo $SSH_CMD
#cat $SSH_CMD | ssh
echo "completed"
echo $NAME, $INSTANCE_NUM, $DAY, $DAY_NUM_OF_WEEK
if [ $INSTANCE_NUM == $DAY_NUM_OF_WEEK ]; then
   echo "Archiving data for "$NAME
#   tar czf $ARCHIVE_DIR/$NAME"_"$DAY".tgz" $BACKUP_DIR
   echo "completed"
fi


#tar czf $ARCHIVE_DIR/$NAME"_"$DAY".tgz" $BACKUP_DIR
# delete archive files older than 30 days                                                                                                  
#find $ARCHIVE_DIR -type f -name $NAME"*.tgz" -mtime +30 -exec rm {} \;
# delete sql dumps in older than 30 days - this means there could be 30 in each archive. 
#find $BACKUP_DIR -type f -name $NAME"*.sql" -mtime +30 -exec rm {} \;

done <$LIST_OF_INSTANCES
