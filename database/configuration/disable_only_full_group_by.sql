/*
===============================================================================
Name:
    Disable ONLY_FULL_GROUP_BY

Category:
    Database Configuration

Purpose:
    Disables MySQL's ONLY_FULL_GROUP_BY mode to allow legacy NMRS/OpenMRS
    reporting queries that use GROUP BY without aggregating all selected columns.

Use Case:
    Run this when report queries fail with errors such as:

    ERROR 1055 (42000):
    Expression #... isn't in GROUP BY clause...

Requirements:
    MySQL user with SUPER or SYSTEM_VARIABLES_ADMIN privilege.

Warning:
    This changes the GLOBAL SQL mode and affects new database sessions.
    Use only when appropriate for your environment.

===============================================================================
*/

-- Disable ONLY_FULL_GROUP_BY
SET GLOBAL sql_mode = '';