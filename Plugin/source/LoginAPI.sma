#include < amxmodx >

#define PLUGIN	"Login System"
#define VERSION	"0.4"
#define AUTHOR	"SUSYABASHTI"

// Enable this to use MySQL Data saving method.
//#define USING_SQL

#if defined USING_SQL

#include < sqlx >
#include < regex >

new const RGX_EMAIL_PATT[ ] = "^^[A-Za-z0-9](([_\.\-]?[a-zA-Z0-9]+)*)@([A-Za-z0-9]+)(([\.\-]?[a-zA-Z0-9]+)*)\.([A-Za-z]{2,})$";

// Here change website url
new const WEBSITE[ ] = "http://www.example.com/index.php";

#define SQL_HOST		"host"
#define SQL_DB		"database"
#define SQL_USER		"username"
#define SQL_PASS		"password"
#define SQL_TABLE	"tablename"

#define MAX_MAIL_LEN	64
#define MAIL	g_szMail[ iIndex ]

new Handle:g_hTuple;
new Handle:g_hConn;
new Trie:g_tMails;
new g_szMail[ 33 ][ MAX_MAIL_LEN ];
new Regex:g_Rgx_Email;

#else

#include < fvault >

new const FILE[ ] = "Passwords";

#endif

#define MAX_PASS_LEN	32
#define MAX_IP_LEN	48
#define MAX_AUTH_LEN	35
#define AUTHID		g_szAuth[ iIndex ]
#define IP		g_szIp[ iIndex ]
#define PASSWORD	g_szPassword[ iIndex ]

#define TASK_KICK		100
#define TASKID_KICK		( iTaskID - TASK_KICK )

// Try changing the value of this const if the player isn't seeing the menu after connect.
const Float:MENU_DELAY =	1.3;

new Trie:g_tPasswords;
new Trie:g_tAuto;

enum _:PluginFwds
{
	Fwd_PreLog,
	Fwd_PostLog
};

enum LogType
{
	LOG_SIGN,
	LOG_LOGIN
};

enum PlayerStatus
{
	NOT_EXIST,
	NOT_LOGGED,
	LOGGED
};

new const STATUS_NAME[ PlayerStatus ][ ] =
{
	"Sign up", 
	"Login",
	"Change Password"
};

new g_iForward[ PluginFwds ];
new g_iFwdResult;

new PlayerStatus:g_iStatus[ 33 ];

new g_szAuth[ 33 ][ MAX_AUTH_LEN ];
new g_szIp[ 33 ][ MAX_IP_LEN ];
new g_szPassword[ 33 ][ MAX_PASS_LEN ];
new g_iKickTime[ 33 ];
new g_iAttempts[ 33 ];

new g_cKickTime;
new g_cMaxAttempts;

public plugin_init( )
{
	register_plugin( PLUGIN, VERSION, AUTHOR );
	
	// Forwards
	
	g_iForward[ Fwd_PreLog ]	=	CreateMultiForward( "Player_Prelogin", ET_CONTINUE, FP_CELL, FP_CELL );
	g_iForward[ Fwd_PostLog ]	=	CreateMultiForward( "Player_Postlogin", ET_STOP, FP_CELL, FP_CELL );
	
	// Player Commands \w SQL

	#if defined USING_SQL
	
	register_clcmd( "ls_set_email", "cmd_Email" );
	
	#endif

	register_clcmd( "ls_set_password", "cmd_Password" );
	register_clcmd( "say /login", "cmd_Login" );
	
	// Plugin CVars
	
	g_cKickTime	=	register_cvar( "ls_kick_time", "60", ADMIN_IMMUNITY );
	g_cMaxAttempts	=	register_cvar( "ls_max_attempts", "3", ADMIN_IMMUNITY );
	
	// Load Data From File / DB
	
	Load_Passwords( );
}

public plugin_end( )
{
	TrieDestroy( g_tAuto );
	TrieDestroy( g_tPasswords );
	
	#if defined USING_SQL
	
	TrieDestroy( g_tMails );
	regex_free( g_Rgx_Email );
	SQL_FreeHandle( g_hTuple );
	
	#endif
}

public plugin_natives( )
{
	register_library( "login_system" );
	
	register_native( "is_player_logged", "native_player_logged" );
}

public native_player_logged( iPlugin, iParams )
{
	return ( g_iStatus[ get_param( 1 ) ] == LOGGED ) ? true : false;
}

Load_Passwords( )
{
	g_tPasswords = TrieCreate( );
	g_tAuto = TrieCreate( );
	
	new szKey[ MAX_AUTH_LEN ], szPass[ MAX_PASS_LEN ], szIp[ MAX_IP_LEN ];
	
	#if !defined USING_SQL
		
	new szData[ 128 ];
	
	for( new i = 0; i < fvault_size( FILE ); ++i )
	{
		fvault_get_keyname( FILE, i, szKey, MAX_AUTH_LEN - 1 );
		fvault_get_data( FILE, szKey, szData, charsmax( szData ) );
		
		remove_quotes( szData );
		parse( szData, szPass, MAX_PASS_LEN - 1, szIp, MAX_IP_LEN - 1 );
		
		log_amx( "%s %s", szPass, szIp );
		
		TrieSetString( g_tPasswords, szKey, szPass );
		TrieSetString( g_tAuto, szKey, szIp );
	}

	#else
	
	new iError, szError[ 512 ], szMail[ MAX_PASS_LEN ];
	g_tMails = TrieCreate( );
	g_Rgx_Email = regex_compile( RGX_EMAIL_PATT, iError, szError, charsmax( szError ) );
	
	if( g_Rgx_Email == REGEX_PATTERN_FAIL )
	{
		log_amx( "Failed to compile regex pattern: %s", szError );
		return;
	}
	
	g_hTuple = SQL_MakeDbTuple( SQL_HOST, SQL_USER, SQL_PASS, SQL_DB );
	
	if( g_hTuple == Empty_Handle )
	{
		set_fail_state( "Invalid Handle: Database Tuple." );
		return;
	}
	
	g_hConn = SQL_Connect( g_hTuple, iError, szError, charsmax( szError ) );
	
	if( g_hConn == Empty_Handle )
	{
		set_fail_state( szError );
		return;
	}
	
	new Handle:hQuery = SQL_PrepareQuery( g_hConn, "SELECT * FROM `%s` ;", SQL_TABLE );
	
	if( !SQL_Execute( hQuery ) )
	{
		SQL_QueryError( hQuery, szError, charsmax( szError ) );
		set_fail_state( szError );
	}
	
	while( SQL_MoreResults( hQuery ) )
	{
		SQL_ReadResult( hQuery, 0, szKey, MAX_AUTH_LEN - 1 );
		SQL_ReadResult( hQuery, 1, szPass, MAX_PASS_LEN - 1 );
		SQL_ReadResult( hQuery, 2, szIp, MAX_IP_LEN - 1 );
		SQL_ReadResult( hQuery, 3, szMail, MAX_MAIL_LEN - 1 );
		
		TrieSetString( g_tPasswords, szKey, szPass );
		TrieSetString( g_tAuto, szKey, szIp );
		TrieSetString( g_tMails, szKey, szMail );
	}
	
	SQL_FreeHandle( g_hConn );
	
	#endif
}

public client_putinserver( iIndex )
{
	g_iAttempts[ iIndex ] = 0;
	PASSWORD[ 0 ] = 0;
	
	#if defined USING_SQL
	
	MAIL[ 0 ] = 0;
	
	#endif
	
	GetPlayerStatus( iIndex );
	
	if( g_iStatus[ iIndex ] != LOGGED )
	{
		// Open the menu after a certain amount of time so there will be no problems.
		set_task( MENU_DELAY, "Task_ShowMenu", iIndex );
	}
}

public Task_ShowMenu( iIndex )
{
	if( !is_user_connected( iIndex ) )
		return;
		
	Player_Login( iIndex );
	g_iKickTime[ iIndex ] = get_pcvar_num( g_cKickTime );
	
	set_task( 0.1, "Task_Kick", iIndex + TASK_KICK );
}

public Task_Kick( iTaskID )
{
	if( !is_user_connected( TASKID_KICK ) || g_iStatus[ TASKID_KICK ] == LOGGED )
		return;
		
	if( g_iKickTime[ TASKID_KICK ]-- <= 0 )
	{
		server_cmd( "kick #%d ^"You didn't login and therefore got kicked from this server!", get_user_userid( TASKID_KICK ) );
		return;
	}
		
	set_hudmessage( 0, 100, 200, -1.0, 0.40, 0, 1.0, 1.0, 0.0, 0.1 );
	show_hudmessage( TASKID_KICK, "[Login System]^nYou have %i seconds to login^nor you will be kicked.", g_iKickTime[ TASKID_KICK ] );
	
	set_task( 1.0, "Task_Kick", iTaskID );
}
public client_disconnect( iIndex )
{
	Save( iIndex );
}

public cmd_Login( iIndex )
{
	Player_Login( iIndex );
	return PLUGIN_HANDLED;
}

Player_Login( iIndex )
{
	new iMenu, szBuffer[ 128 ], iCallback;
	formatex( szBuffer, charsmax( szBuffer ), "\yLogin System^n\dStatus:\r %sogged in", ( g_iStatus[ iIndex ] == LOGGED ) ? "L" : "Not l" );
	iMenu = menu_create( szBuffer, "menuHandle_Login" );
	iCallback = menu_makecallback( "menuCb_Login" );
	
	#if defined USING_SQL
	
	formatex( szBuffer, charsmax( szBuffer ), "Email:\y %s", MAIL[ 0 ] ? MAIL : "None" );
	menu_additem( iMenu, szBuffer, "", _, iCallback );
	
	#endif
	
	formatex( szBuffer, charsmax( szBuffer ), "Password:\y %s", PASSWORD[ 0 ] ? PASSWORD : "None" );
	menu_additem( iMenu, szBuffer, "" );
	
	if( g_iStatus[ iIndex ] == NOT_LOGGED )
	{
		if( g_iAttempts[ iIndex ] )
			formatex( szBuffer, charsmax( szBuffer ), "%s\r (%i attempts left)",\
			STATUS_NAME[ g_iStatus[ iIndex ] ], ( get_pcvar_num( g_cMaxAttempts ) - g_iAttempts[ iIndex ] ) );
		else
			formatex( szBuffer, charsmax( szBuffer ), "%s", STATUS_NAME[ g_iStatus[ iIndex ] ] );
	}
	
	else
	{
		formatex( szBuffer, charsmax( szBuffer ), "%s^n", STATUS_NAME[ g_iStatus[ iIndex ] ] );
	}
	
	menu_additem( iMenu, szBuffer, "", _, iCallback );
	
	#if defined USING_SQL
		
	if( g_iStatus[ iIndex ] == NOT_LOGGED )
	{
		formatex( szBuffer, charsmax( szBuffer ), "Forgot Password" );
		menu_additem( iMenu, szBuffer, "" );
	}
	
	#endif
	
	if( g_iStatus[ iIndex ] != LOGGED )
		menu_setprop( iMenu, MPROP_EXIT, MEXIT_NEVER );
	
	menu_display( iIndex, iMenu );
}

public menuCb_Login( iIndex, iMenu, iItem )
{
	#if defined USING_SQL
	
	if( !iItem )
	{
		if( g_iStatus[ iIndex ] == NOT_LOGGED )
			return ITEM_DISABLED;
		
		return ITEM_ENABLED;
	}
	
	new iReturn;
	
	if( regex_match_c( MAIL, g_Rgx_Email, iReturn ) < 1 )
		return ITEM_DISABLED;
		
	#endif
	
	if( !PASSWORD[ 0 ] )
		return ITEM_DISABLED;
	
	if( g_iStatus[ iIndex ] == LOGGED )
	{
		if( Passwords_Match( iIndex ) )
			return ITEM_DISABLED;
			
		return ITEM_ENABLED;
	}
	
	return ITEM_ENABLED;
}

public menuHandle_Login( iIndex, iMenu, iItem )
{
	menu_destroy( iMenu );
	
	if( iItem == MENU_EXIT )
		return;
	
	#if !defined USING_SQL
		iItem++
	#endif
	
	switch( iItem )
	{
		#if defined USING_SQL
		
		case 0:
		{
			client_cmd( iIndex, "messagemode ls_set_email" );
		}
		
		case 3:
		{
			show_motd( iIndex, WEBSITE, "Forgot Password?" );
		}
		
		#endif
		
		case 1:
		{
			client_cmd( iIndex, "messagemode ls_set_password" );
		}
		
		case 2:
		{
			if( g_iStatus[ iIndex ] == NOT_EXIST )
			{
				ExecuteForward( g_iForward[ Fwd_PreLog ], g_iFwdResult, iIndex, LOG_SIGN );
				
				if( g_iFwdResult != PLUGIN_CONTINUE )
					return;
				
				g_iStatus[ iIndex ] = LOGGED;
				
				TrieSetString( g_tPasswords, AUTHID, PASSWORD );
				TrieSetString( g_tAuto, AUTHID, IP );
				
				#if defined USING_SQL
				
				TrieSetString( g_tMails, AUTHID, MAIL );
				
				#endif
				
				Save( iIndex );
				
				set_hudmessage( 0, 100, 200, -1.0, 0.40, 0, 1.0, 1.0, 0.0, 0.1 );
				show_hudmessage( iIndex, "You've signed up successfully, auto-login is enabled^nif your ip address is changed you will have to login manually again." );
				
				ExecuteForward( g_iForward[ Fwd_PostLog ], g_iFwdResult, iIndex, LOG_SIGN );
			}
			
			else if( g_iStatus[ iIndex ] == NOT_LOGGED )
			{
				if( Passwords_Match( iIndex ) )
				{
					ExecuteForward( g_iForward[ Fwd_PreLog ], g_iFwdResult, iIndex, LOG_LOGIN );
					
					if( g_iFwdResult != PLUGIN_CONTINUE )
						return;
					
					g_iStatus[ iIndex ] = LOGGED;
					
					TrieSetString( g_tAuto, AUTHID, IP );
					
					set_hudmessage( 0, 100, 200, -1.0, 0.40, 0, 1.0, 1.0, 0.0, 0.1 );
					show_hudmessage( iIndex, "You've logged-in successfully, auto-login is now enabled." );
					
					ExecuteForward( g_iForward[ Fwd_PostLog ], g_iFwdResult, iIndex, LOG_LOGIN );
					
					return;
				}
				
				g_iAttempts[ iIndex ]++;
				
				if( g_iAttempts[ iIndex ] >= get_pcvar_num( g_cMaxAttempts ) )
				{
					server_cmd( "kick #%d ^"You've failed logging in too many times!^"", get_user_userid( iIndex ) );
					return;
				}
				
				Player_Login( iIndex );
			}
			
			else
			{
				TrieSetString( g_tPasswords, AUTHID, PASSWORD );
				
				#if defined USING_SQL
				
				TrieSetString( g_tMails, AUTHID, MAIL );
				
				#endif
				
				set_hudmessage( 0, 100, 200, -1.0, 0.40, 0, 1.0, 1.0, 0.0, 0.1 );
				show_hudmessage( iIndex, "You've changed your login credentials successfully." );
				
				Save( iIndex );
			}
		}
	}
}

#if defined USING_SQL

public cmd_Email( iIndex )
{
	new iReturn;
	
	read_argv( 1, MAIL, MAX_MAIL_LEN - 1 );
	trim( MAIL );
	
	if( regex_match_c( MAIL, g_Rgx_Email, iReturn ) < 1 )
		copy( MAIL, MAX_MAIL_LEN - 1, "Invalid Email" );
		
	Player_Login( iIndex );
	return PLUGIN_HANDLED;
}

#endif
		
public cmd_Password( iIndex )
{
	read_argv( 1, PASSWORD, MAX_PASS_LEN - 1 );
	
	replace_all( PASSWORD, MAX_PASS_LEN -1, " ", "" );
	trim( PASSWORD );
	Player_Login( iIndex );
	
	return PLUGIN_HANDLED;
}

Save( iIndex )
{
	if( g_iStatus[ iIndex ] != LOGGED )
		return;
	
	if( !TrieGetString( g_tPasswords, AUTHID, PASSWORD, MAX_PASS_LEN - 1 ) )
		return;
	
	#if !defined USING_SQL
	
	new szData[ 128 ];
	formatex( szData, charsmax( szData ), "^"%s^" ^"%s^"", PASSWORD, IP );
	fvault_pset_data( FILE, AUTHID, szData );
	
	#else
	
	TrieGetString( g_tMails, AUTHID, MAIL, MAX_MAIL_LEN - 1 );
	SQL_Real_Escape_String( PASSWORD, MAX_PASS_LEN - 1 );
	
	static szQuery[ 512 ];
	formatex( szQuery, charsmax( szQuery ), "INSERT IGNORE INTO `%s` ( `authid`, `password`, `user_ip`, `email` ) VALUES ( '%s', '%s', '%s', '%s' ) \
	ON DUPLICATE KEY UPDATE `password` = '%s', `user_ip` = '%s', `email` = '%s' ;", SQL_TABLE, AUTHID, PASSWORD, IP, MAIL, PASSWORD, IP, MAIL );
	
	SQL_ThreadQuery( g_hTuple, "ThreadQuery_FreeHandle", szQuery );
	
	#endif
}

#if defined USING_SQL

public ThreadQuery_FreeHandle( FailState, Handle:hQuery, Error[], Errcode, Data[], DataSize )
{
	if( FailState != TQUERY_SUCCESS )
	{
		log_amx( "[Login System] There was error saving player to database. Error(%d): %s", Errcode, Error );
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

SQL_Real_Escape_String( szOutput[ ], const iLen )
{
	replace_all( szOutput, iLen, "'", "\'" )
	replace_all( szOutput, iLen, "%", "\%" )
}


#endif

bool:Passwords_Match( iIndex )
{
	new szOldPass[ 32 ];
	if( !TrieGetString( g_tPasswords, AUTHID, szOldPass, MAX_PASS_LEN - 1 ) )
		return false;
	
	if( !strcmp( szOldPass, PASSWORD ) )
		return true;
		
	return false;
}

PlayerStatus:GetPlayerStatus( iIndex )
{
	new szRecorded[ MAX_IP_LEN ];
	get_user_ip( iIndex, IP, MAX_IP_LEN - 1, 1 );
	get_user_authid( iIndex, AUTHID, MAX_AUTH_LEN - 1 );
	
	if( !TrieKeyExists( g_tPasswords, AUTHID ) )
		return g_iStatus[ iIndex ] = NOT_EXIST;
	
	TrieGetString( g_tAuto, AUTHID, szRecorded, MAX_IP_LEN - 1 );
	if( !strcmp( IP, szRecorded ) )
	{
		TrieGetString( g_tPasswords, AUTHID, PASSWORD, MAX_PASS_LEN - 1 );
		
		#if defined USING_SQL
		
		TrieGetString( g_tMails, AUTHID, MAIL, MAX_MAIL_LEN - 1 );

		#endif
		
		ExecuteForward( g_iForward[ Fwd_PreLog ], g_iFwdResult, iIndex, LOG_LOGIN );
		
		if( g_iFwdResult != PLUGIN_CONTINUE )
			return NOT_LOGGED;
			
		g_iStatus[ iIndex ] = LOGGED;
			
		ExecuteForward( g_iForward[ Fwd_PostLog ], g_iFwdResult, iIndex, LOG_LOGIN );
		
		return LOGGED;
	}
		
	return g_iStatus[ iIndex ] = NOT_LOGGED;
}
