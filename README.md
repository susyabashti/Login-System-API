 # Login System API ![](https://img.shields.io/badge/release-v0.4-brightgreen.svg) ![](https://img.shields.io/badge/engine-GOLDSRC-yellow.svg) ![](https://img.shields.io/badge/coder-SUSYABASHTI-lightgrey.svg)

**AMXX Plugin** written by me to those who want a layer of security for their players unique id in the server.
> [Changelog](https://github.com/susyabashti/Login-System-API/blob/master/CHANGELOG.md "Changelog")


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
3. Open the .sma file and uncomment this line:
```cpp
#define USING_SQL
```
4. And also edit this lines:
```cpp
new const WEBSITE[ ] = "http://www.example.com/index.php";

#define SQL_HOST		"host"
#define SQL_DB		"database"
#define SQL_USER		"username"
#define SQL_PASS		"password"
#define SQL_TABLE	"tablename"
```

5. Run this SQL command in your web:
```sql
CREATE TABLE `database_name`.`table_name` ( `authid` VARCHAR(35) NOT NULL , `password` VARCHAR(32) NOT NULL , `user_ip` VARCHAR(48) NOT NULL , `email` VARCHAR(64) NOT NULL, UNIQUE `authid` (`authid`)) ;
```

6. Put compiled file in "plugins" folder, and restart the server.
7. Enjoy!

## Plugin CVars

```cpp
ls_kick_time "X" // Default: 60 Change the amount of time the player have before getting kicked.
ls_max_attempts "X" // Default: 3 Change the max attempts to login before kicking the player.
```


## Plugin API

```cpp
#if defined _login_api_included
  #endinput
#endif
#define _login_api_included

#pragma reqlib	"login_system"

enum LogType
{
	LOG_SIGN,	// First time player logged in ( signed up )
	LOG_LOGIN
};

/* * 
   *		Checks whether the player is logged or not.
   *		Returns true, else false.
*  */

native is_player_logged( const iIndex );

/* * 
   *	Called whenever player is trying to login.
   *	If returned PLUGIN_CONTINUE, login will continue. To stop login proccess return PLUGIN_HANDLED / PLUGIN_HANDLED_MAIN.
*  */

forward Player_Prelogin( const iIndex, const LogType:iType );

/* * 
   *	Called after the player has logged in.
   *	No return.
*  */

forward Player_Postlogin( const iIndex, const LogType:iType );

```

## Web Part Example
http://4honor.cl2host.co.il/rps/


## Support
if you find any bugs, please report.
