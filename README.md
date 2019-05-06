 # Login System API ![](https://img.shields.io/badge/release-v0.4-brightgreen.svg)

**AMXX Plugin** written by me to those who want a layer of security for their players unique id in the server.

## Requirements
* Updated CS 1.6 Server.
* AMX Mod X 1.8.2 installed.
* [FVault](https://forums.alliedmods.net/showthread.php?t=76453 "FVault").inc (for Coders).
##### Optional
* Web hosting with Remote access privilege.

## Installation
1. Download the plugin.
2. If you are not going to use MySQL saving method then just put the .amxx files in the "plugins" folder or compile it yourself.
##### Continue only  if you are using MySQL saving method
3. Open the .sma file and edit this lines:

```cpp
new const WEBSITE[ ] = "http://www.example.com/index.php";

#define SQL_HOST		"host"
#define SQL_DB		"database"
#define SQL_USER		"username"
#define SQL_PASS		"password"
#define SQL_TABLE	"tablename"
```

4. Run this SQL command in your web:
```sql
CREATE TABLE `database_name`.`table_name` ( `authid` VARCHAR(35) NOT NULL , `password` VARCHAR(32) NOT NULL , `user_ip` VARCHAR(48) NOT NULL , `email` VARCHAR(64) NOT NULL, UNIQUE `authid` (`authid`)) ;
```

5. Put compiled file in "plugins" folder, and restart the server.
6. Enjoy!

## Web Part Example
http://4honor.cl2host.co.il/rps/

------------


## Support
if you find any bugs, please report.
