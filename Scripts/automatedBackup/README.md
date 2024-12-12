Automated Incremental Backup Script

1. Description

	It is a shell script that automates the backup of specified directory to a amazon S3 bucket. It performs incremental backups and logging of backup activities. 

2. Detailed Explanation
	
	The first section includes initial configuration, where necessary variables like the source and destination are set.

	The second section includes functions to write log message to the log file and clean old logs for log rotation.

	The third section includes functions to create a lock file to prevent simultaneous run of multiple instances of the backup script and to remove the lock once the script is completed.

	The fourth section includes a function to check if requirements are met. It checks aws CLI being installed and the source and destination directories being initialized to correct parameters.

	The fifth section includes a function to perform backup. The aws `--endpoint-url`  is included because it was used with localstack, it can be removed if your are using actual Amazon S3 service.

	Finally, the last section includes function calls to begin execution.

3. How to use 

	 Save the script to /usr/local/bin/backup.sh and make it executable:

		sudo chmod +x /usr/local/bin/backup.sh
	
	Create necessary directories and set permissions:

		sudo mkdir -p /var/backup
		sudo mkdir -p /var/log/backup
		sudo chmod 755 /var/backup
		sudo chmod 755 /var/log/backup
		
	Edit the crontab file:

		sudo crontab -e

	Add a cron schedule that works for you: (I scheduled it to run at 6 am everyday)

		0 6 * * * /usr/local/bin/backup.sh
