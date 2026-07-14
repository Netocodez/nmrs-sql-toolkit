/*
===============================================================================
Name:
    Post Restore Configuration

Purpose:
    Common configuration commands to run after restoring or setting up
    an NMRS/OpenMRS database.

===============================================================================
*/

-- Fix GROUP BY errors caused by ONLY_FULL_GROUP_BY
SET GLOBAL sql_mode = '';

-- Grant privileges to OpenMRS user
GRANT ALL PRIVILEGES ON *.* TO 'openmrs_user'@'localhost';

FLUSH PRIVILEGES;