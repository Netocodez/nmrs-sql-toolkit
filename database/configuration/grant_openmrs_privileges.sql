/*
===============================================================================
Name:
    Grant Privileges to openmrs_user

Category:
    Database Configuration

Purpose:
    Grants full privileges to the OpenMRS database user.

Warning:
    Intended for development or controlled environments.
    Review before using in production.

===============================================================================
*/

GRANT ALL PRIVILEGES ON *.* TO 'openmrs_user'@'localhost';
FLUSH PRIVILEGES;