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
