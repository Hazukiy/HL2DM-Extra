#include <sourcemod>
#include <sdktools>
#include <morecolors>

#include "HLExtra-Player.sp"

//Terminate
#pragma semicolon 1
#pragma newdecls required

static char _pluginVersion[] = "1.0.0.1";
static char _ownerID[] = "[U:1:13299075]";
static char _chatPrefix[] = "[HL2DM-Ex]";
static char _botNames[][] = 
{ 
	"Gordon", 
	"Alyx", 
	"Jerry", 
	"Mr.Freeman",
	"Orange"
};

//Standard spawn models
static char _standardModels[][] = 
{
	"models/humans/group03/female_01.mdl",
	"models/humans/group03/female_02.mdl",
	"models/humans/group03/female_03.mdl",
	"models/humans/group03/female_04.mdl",
	"models/humans/group03/female_05.mdl",
	"models/humans/group03/female_06.mdl",
	"models/humans/group03/male_01.mdl",
	"models/humans/group03/male_02.mdl",
	"models/humans/group03/male_03.mdl",
	"models/humans/group03/male_04.mdl",
	"models/humans/group03/male_05.mdl",
	"models/humans/group03/male_06.mdl",
	"models/humans/group03/male_07.mdl",
	"models/humans/group03/male_08.mdl",
	"models/humans/group03/male_09.mdl"
};

//Custom models
static char _customModels[][] = 
{
	"models/alyx.mdl", 
	"models/barney.mdl",
	"models/breen.mdl",
	"models/kleiner.mdl",
	"models/monk.mdl",
	"models/mossman.mdl",
	"models/police.mdl",
	"models/combine_soldier.mdl",
	"models/combine_super_soldier.mdl",
	"models/combine_soldier_prisonguard.mdl"
};

static char _hurtSounds[][] = 
{ 
	"ambient/voices/citizen_beaten1.wav", 
	"ambient/voices/citizen_beaten2.wav", 
	"ambient/voices/citizen_beaten3.wav", 
	"ambient/voices/citizen_beaten4.wav",
	"ambient/voices/citizen_beaten5.wav"
};

static char _customSounds[][] = 
{ 
	"hitmarker.mp3",
	"player/breathe1.wav",
	"HL1/fvox/health_critical.wav"
};

static char _databaseName[] = "HL2DMExtra";
static char _playerTableName[] = "Players";
static Handle _databaseHandle;

static int _serverUptime;
static Handle _serverUptimeTimer;

public Plugin myinfo = {
	name        = "HL2DM Extra",
	author      = "SirTiggs",
	description = "Provices more functionality to the base game",
	version     = _pluginVersion,
	url         = "https://github.com/Hazukiy/HL2DM-Extra"
};


//* REGION Forwards *//
public void OnPluginStart() {
	//Client commands
	RegConsoleCmd("sm_chatsound", Command_ChatSound, "Enables chat sound.");
	RegConsoleCmd("sm_modelstore", Command_ModelStore, "Opens the model store.");
	RegConsoleCmd("sm_buymodel", Command_BuyModel, "Buys a model from the store.");
	RegConsoleCmd("sm_changemodel", Command_ChangeModel, "Change your player model.");

	//Admin commands
	RegAdminCmd("sm_reload", Command_ReloadServer, ADMFLAG_ROOT, "Reloads the server.");
	RegAdminCmd("sm_getauth", Command_GetAuth, ADMFLAG_ROOT, "Returns client auth id.");
	RegAdminCmd("sm_testsound", Command_TestSound, ADMFLAG_ROOT, "Returns client auth id.");
	RegAdminCmd("sm_createclient", Command_CreateFakeClient, ADMFLAG_ROOT, "Creates a fake client.");
	//RegAdminCmd("sm_setmodel", Command_SetModel, ADMFLAG_ROOT, "Set a players model.");

	//Hooks
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);

	//Precache standard models
	for(int i = 0; i < sizeof(_standardModels); i++) {
		bool result = PrecacheModel(_standardModels[i], true);
		if(result) {
			PrintToServer("%s Model Precache Result: [%s] Passed (%d/%d)", _chatPrefix, _standardModels[i], i + 1, sizeof(_standardModels));
		}
		else {
			PrintToServer("%s WARNING Precache result failed: [%s] (%d/%d)", _chatPrefix, _standardModels[i], i + 1, sizeof(_standardModels));
		}
	}

	//Precache custom models
	for(int i = 0; i < sizeof(_customModels); i++) {
		bool result = PrecacheModel(_customModels[i], true);
		if(result) {
			PrintToServer("%s Model Precache Result: [%s] Passed (%d/%d)", _chatPrefix, _customModels[i], i + 1, sizeof(_customModels));
		}
		else {
			PrintToServer("%s WARNING Precache result failed: [%s] (%d/%d)", _chatPrefix, _customModels[i], i + 1, sizeof(_customModels));
		}
	}

	//Override chat
	AddCommandListener(Event_PlayerChat, "say");
	AddCommandListener(Event_Blocked, "cl_playermodel");

	//Initialise SQL
	SQL_Initialise();
}

public void OnMapStart() {
	//Precache hurt sounds
	for(int i = 0; i < sizeof(_hurtSounds); i++) {
		bool result = PrecacheSound(_hurtSounds[i], true);
		if(result) {
			PrintToServer("%s Sound Precache Result: [%s] Passed (%d/%d)", _chatPrefix, _hurtSounds[i], i + 1, sizeof(_hurtSounds));
		}
		else {
			PrintToServer("%s WARNING Preache result failed: [%s] (%d/%d)", _chatPrefix, _hurtSounds[i], i + 1, sizeof(_hurtSounds));
		}
	}
	
	//Dynamically add to table and precache sounds
	for(int i = 0; i < sizeof(_customSounds); i++) {
		char path[100];

		Format(path, sizeof(path), "sound/%s", _customSounds[i]);
		
		AddFileToDownloadsTable(path);

		bool result = PrecacheSound(_customSounds[i], true);
		if(result) {
			PrintToServer("%s Sound Precache Result: [%s] Passed (%d/%d)", _chatPrefix, _customSounds[i], i + 1, sizeof(_customSounds));
		}
		else {
			PrintToServer("%s WARNING Preache result failed: [%s] (%d/%d)", _chatPrefix, _customSounds[i], i + 1, sizeof(_customSounds));
		}
	}

	_serverUptimeTimer = CreateTimer(1.0, Timer_CalculateUptime,_,TIMER_REPEAT);
}

public void OnMapEnd() {
	if(_serverUptimeTimer != null) {
		KillTimer(_serverUptimeTimer, true);	
	}

	if(_databaseHandle != null) {
		KillTimer(_databaseHandle, true);
	}

	_serverUptime = 0;
}

public void OnClientPostAdminCheck(int client) {	
	SQL_Load(client);
}

public void OnClientDisconnect(int client) {
	//Save the player
	SQL_Save(client);

	if(!IsFakeClient(client)) {
		//Cleanup
		Player player = Player(client);
		player.Kills = 0;
		player.Deaths = 0;
		player.Money = 0;
		player.TimePlayed = 0;
		player.IsAdmin = false;
		player.UseChatSound = true;
		player.HasGodmode = false;

		if(player.Hud != null) {
			KillTimer(player.Hud, false);
		}

		if(player.LoyalityCheck != null) {
			KillTimer(player.LoyalityCheck, false);
		}

		if(player.Listener != null) {
			KillTimer(player.Listener, false);
		}
	}
}

//* REGIONEND Forwards *//





//* REGION EventHandlers *//
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	static int victim = 0, attacker = 0;
	char victimName[32], attackerName[32], weapon[255];

	victim = GetClientOfUserId(event.GetInt("userid", 0));
	attacker = GetClientOfUserId(event.GetInt("attacker", 0));

	if (victim == 0) return Plugin_Handled;
	if (attacker == 0) return Plugin_Handled; 

	if(victim == attacker) {
		CPrintToChat(victim, "{gold}You killed yourself.");
		return Plugin_Handled;
	}

	//Get the weapon used 
	event.GetString("weapon", weapon, sizeof(weapon));

	//Victim
	if(IsClientConnected(victim) && IsClientInGame(victim) && !IsFakeClient(victim)) {
		if(!IsClientInGame(attacker)) {
			CPrintToChat(victim, "{gold}You've been killed.");
			return Plugin_Handled;
		}

		int healthLeft = GetClientHealth(attacker);
		GetClientName(attacker, attackerName, sizeof(attackerName));
		CPrintToChat(victim, "{gold}You've been killed with a {red}%s{gold} by {red}%s{gold} ({green}%d/100 hp{gold})", weapon, attackerName, healthLeft);

		IncreaseDeaths(victim);
		SQL_Save(victim);
	}

	//Attacker
	if(IsClientConnected(attacker) && IsClientInGame(attacker)) {
		GetClientName(victim, victimName, sizeof(victimName));

		int money = CalculateMoneyReward(attacker, weapon);

		CPrintToChat(attacker, "{gold}You killed {red}%s{gold} with a {red}%s{gold} earning {green}$%d", victimName, weapon, money);
		IncreaseKills(attacker);
		SQL_Save(attacker);
	}

	return Plugin_Continue;
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) {
	char clientName[32], networkID[32], ipAddress[32];

	event.GetString("name", clientName, sizeof(clientName));
	event.GetString("networkid", networkID, sizeof(networkID));
	event.GetString("address", ipAddress, sizeof(ipAddress));

	//Output
	CPrintToChatAll("{purple}%s{gold} {red}%s{gold} has connected to the server.", _chatPrefix, clientName);
	PrintToServer("%s Player %s connected: IP = %s | SteamID = %s", _chatPrefix, clientName, ipAddress, networkID);

	event.BroadcastDisabled = true;
	dontBroadcast = true;

	return Plugin_Handled;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	char playerName[32], reason[32], networkID[32];
	event.GetString("name", playerName, sizeof(playerName));
	event.GetString("reason", reason, sizeof(reason));
	event.GetString("networkID", networkID, sizeof(networkID));

	CPrintToChatAll("{purple}%s{gold} {red}%s{gold} has disconnected from the server.", _chatPrefix, playerName);
	PrintToServer("Player %s disconnected: SteamID = %s | Reason: %s", playerName, networkID, reason);

	event.BroadcastDisabled = true;
	dontBroadcast = true;
	return Plugin_Handled;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));

	//Play sound to attacker
	if(attacker > 0) {
		EmitSoundToClient(attacker, "hitmarker.mp3", SOUND_FROM_PLAYER, SNDCHAN_STATIC, 100);
	}

	//Play sound to victim
	if(victim > 0) {
		int indexVal = GetRandomInt(0, sizeof(_hurtSounds)-1);
		ClientCommand(victim, "play %s", _hurtSounds[indexVal]);
	}

	return Plugin_Handled;
}

public Action Event_PlayerChat(int client, const char[] command, int args) {
	char message[512], clientName[32], authID[32];

	GetCmdArg(1, message, sizeof(message));
	GetClientName(client, clientName, sizeof(clientName));
	GetClientAuthId(client, AuthId_Steam3, authID, sizeof(authID));
	
	if(message[0] == '/') return Plugin_Handled;

	for(int i = 1; i < MaxClients + 1; i++){
		if(IsClientConnected(i) && IsClientInGame(i)){
			Player player = Player(i);		
			if(player.UseChatSound) {
				ClientCommand(i, "play %s", "Friends/friend_join.wav");
			}
		}
	}

	Player player = Player(client);
	if(player.IsAdmin) {
		CPrintToChatAll("{bad}OWNER{main}|{sirtiggs}%s{main}: {green}%s", clientName, message);
	}
	else {
		CPrintToChatAll("{white}PLAYER{main}({red}%s{main})|{good}%s{main}: {green}%s", authID, clientName, message);
	}
	return Plugin_Handled;
}

public Action Event_Blocked(int client, const char[] command, int args) {
	CPrintToChat(client, "{red}This command is banned.");
	return Plugin_Handled;
}

public Action Event_PlayerModelBlock(int client, const char[] command, int args) {
	CPrintToChat(client, "{purple}%s{bad}Command blocked; event recorded.", _chatPrefix);
	return Plugin_Handled;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int userID = GetClientOfUserId(event.GetInt("userid", 0));
	Player player = Player(userID);

	if(player.Model == 0) {
		//Assign random model from list
		int randomModel = GetRandomInt(0, sizeof(_standardModels));
		SetEntityModel(userID, _standardModels[randomModel]);
	}
	else {
		SetEntityModel(userID, _customModels[player.Model]);
	}

	//Default admin skin
	if(player.IsAdmin) {
		if(player.Model == 0) {
			player.Model = 8;
			SQL_Save(userID);
		}

		//Start a timer
		CreateTimer(1.5, Timer_PlayerSpawn, userID);
	}

	return Plugin_Handled;
}
//* REGIONEND EventHandlers *//



//* REGION Commands *//
public Action Command_ChatSound(int client, int args) {
	Player player = Player(client);
	if(player.UseChatSound) {
		player.UseChatSound = false;
		CPrintToChat(client, "{purple}%s{gold} Your chat sounds have been {red}disabled.", _chatPrefix);
	}
	else {
		player.UseChatSound = true;
		CPrintToChat(client, "{purple}%s{gold} Your chat sounds have been {green}enabled.", _chatPrefix);
	}

	return Plugin_Handled;
}

public Action Command_GetAuth(int client, int args) {
	char authID[255];
	GetClientAuthId(client, AuthId_Steam3, authID, sizeof(authID));

	CPrintToChat(client, "{purple}%s{gold} Your auth is: {green}%s", _chatPrefix, authID);

	return Plugin_Handled;
}

public Action Command_ReloadServer(int client, int args) {
	char mapName[32], playerName[32], format[255], ip[12], auth[32];

	GetCurrentMap(mapName, sizeof(mapName));
	GetClientName(client, playerName, sizeof(playerName));
	GetClientIP(client, ip, sizeof(ip), false);
	GetClientAuthId(client, AuthId_Steam3, auth, sizeof(auth));

	Format(format, sizeof(format), "Server reloaded by user %s(%s): %s", playerName, ip, auth);
	LogMessage(format);
	ForceChangeLevel(mapName, format);
	return Plugin_Handled;
}

public Action Command_TestSound(int client, int args) {
	EmitSoundToClient(client, "hitmarker.mp3", SOUND_FROM_PLAYER, SNDCHAN_STATIC, 100);
	return Plugin_Handled;
}

public Action Command_CreateFakeClient(int client, int args) {
	char name[100];
	
	int nameIndex = GetRandomInt(0, sizeof(_botNames));

	Format(name, sizeof(name), "Player %s", _botNames[nameIndex]);

	CreateFakeClient(name);

	CPrintToChat(client, "{purple}%s{gold} Fake client %s created.", _chatPrefix, name);

	return Plugin_Handled;
}

public Action Command_ModelStore(int client, int args) {
	CPrintToChat(client, "====Store====\n1. Alyx Model\n2. Barney Model\n3. Breen Model");
	
	return Plugin_Handled;
}

public Action Command_BuyModel(int client, int args) {


	return Plugin_Handled;
}

public Action Command_ChangeModel(int client, int args) {
	CPrintToChat(client, "====Store====\n1. Alyx Model\n2. Barney Model\n3. Breen Model");



	return Plugin_Handled;
}

public Action Command_MyModels(int client, int args) {
	CPrintToChat(client, "====Store====\n1. Alyx Model\n2. Barney Model\n3. Breen Model");



	return Plugin_Handled;
}
//* REGIONEND Commands *//




//* REGION SQL Database *//
static void SQL_InsertNewPlayer(int client) {
	char query[250], playerAuth[32];

	GetClientAuthId(client, AuthId_Steam3, playerAuth, sizeof(playerAuth));

	Format(query, sizeof(query), "INSERT INTO %s ('ID') VALUES ('%s')", _playerTableName, playerAuth);

	SQL_TQuery(_databaseHandle, SQL_InsertCallback, query, client);

	PrintToServer("%s Successfully inserted new profile: %s", _chatPrefix, playerAuth);
}

static void SQL_Load(int client) {
	char query[200], playerAuth[32];

	if(IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client)) {
		
		GetClientAuthId(client, AuthId_Steam3, playerAuth, sizeof(playerAuth));

		Format(query, sizeof(query), "SELECT * FROM `%s` WHERE `ID` = '%s'", _playerTableName, playerAuth);

		SQL_TQuery(_databaseHandle, SQL_LoadCallback, query, client);

		PrintToServer("%s Profile %s loaded.", _chatPrefix, playerAuth);
	}
}

static void SQL_Save(int client) {
	char query[200], playerAuth[32];

	if(!IsFakeClient(client)) {
		GetClientAuthId(client, AuthId_Steam3, playerAuth, sizeof(playerAuth));

		Player player = Player(client);

		Format(query, sizeof(query), "UPDATE %s SET Kills = '%i', Deaths = '%i', Money = '%i', TimePlayed = '%i', IsAdmin = '%i', Model = '%i' WHERE ID = '%s'", _playerTableName, player.Kills, player.Deaths, player.Money, player.TimePlayed, BoolToBit(player.IsAdmin), player.Model, playerAuth);
		
		SQL_TQuery(_databaseHandle, SQL_GenericTQueryCallback, query);
	}
}

static void SQL_Initialise() {
	char error[200];

	_databaseHandle = SQLite_UseDatabase(_databaseName, error, sizeof(error));
	if(_databaseHandle == null) {
		PrintToServer("%s Error at SQL_Initialise: %s", _chatPrefix, error);
		LogError("%s Error at SQL_Initialise: %s", _chatPrefix, error);
	}
	else {
		SQL_CreatePlayerTable();
	}
}

static Action SQL_CreatePlayerTable() {
	char query[600];
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS '%s' ('ID' VARCHAR(32), Kills INT(9) NOT NULL DEFAULT 0, Deaths INT(9) NOT NULL DEFAULT 0, Money INT(9) NOT NULL DEFAULT 0, TimePlayed INT(9) NOT NULL DEFAULT 0, IsAdmin BIT NOT NULL DEFAULT 0, Model INT(9) NOT NULL DEFAULT 0)", _playerTableName);
	SQL_TQuery(_databaseHandle, SQL_GenericTQueryCallback, query);
	return Plugin_Handled;
}

static void SQL_LoadCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if(hndl != null) {
		if(!SQL_GetRowCount(hndl)) {
			SQL_InsertNewPlayer(data);
		}
		else {
			char authID[32];

			GetClientAuthId(data, AuthId_Steam3, authID, sizeof(authID));

			//Load in db values
			Player player = Player(data);
			player.Kills = SQL_FetchInt(hndl, 1);
			player.Deaths = SQL_FetchInt(hndl, 2);
			player.Money = SQL_FetchInt(hndl, 3);
			player.TimePlayed = SQL_FetchInt(hndl, 4);
			player.IsAdmin = BitToBool(SQL_FetchInt(hndl, 5));
			player.Model = SQL_FetchInt(hndl, 6);
			
			//Non-db locals
			player.UseChatSound = true;
			player.HasGodmode = false;

			if(StrEqual(authID, _ownerID)) {
				player.IsAdmin = true;
			}
			else {
				player.IsAdmin = false;
			}
			
			//Set timers
			player.Hud = CreateTimer(1.0, Timer_RenderHud, data, TIMER_REPEAT);
			player.LoyalityCheck = CreateTimer(600.0, Timer_LoyalityCheck, data, TIMER_REPEAT);
			player.Listener = CreateTimer(1.0, Timer_Listener, data, TIMER_REPEAT);

			//Welcome
			ClientCommand(data, "play %s", "vo/Breencast/br_welcome01.wav");

			//Output
			CPrintToChat(data, "{purple}%s{gold} Welcome to HL2DM-Extra Public Server. !motd for commands and information.", _chatPrefix);
		}
	}
	else {
		PrintToServer("%s Found error on LoadPlayer: %s", _chatPrefix, error);
		LogError("%s Found error on LoadPlayer: %s", _chatPrefix, error);
		return;
	}
}

static void SQL_InsertCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if(hndl != null) {
		SQL_Load(data);
	}
	else {
		PrintToServer("%s Error at SQL_InsertCallback: %s", _chatPrefix, error);
		LogError("%s Error at SQL_InsertCallback: %s", _chatPrefix, error);
	}
}

static void SQL_GenericTQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if(hndl == null) {
		PrintToServer("%s Error at SQL_GenericTQueryCallback: %s", _chatPrefix, error);
		LogError("%s Error at SQL_GenericTQueryCallback: %s", _chatPrefix, error);
	}
}
//* REGIONEND SQL Database *//



//* REGION TIMERS *//
public Action Timer_RenderHud(Handle timer, any client) {
	if(IsClientConnected(client) && IsClientInGame(client)) {
		char uptimeText[100], timePlayedText[100], hudText[250];

		//Update player time
		Player player = Player(client);
		player.TimePlayed++;

		//Format times
		FormatTime(uptimeText, sizeof(uptimeText), "Server Uptime: %H Hours %M Minutes %S Seconds", GetServerUptime());
		FormatTime(timePlayedText, sizeof(timePlayedText), "Time Played: %H Hours %M Minutes", player.TimePlayed);

		SetHudTextParams(0.015, -0.95, 1.0, 0, 217, 255, 255, 0);
		ShowHudText(client, -1, "%s\n%s", uptimeText, timePlayedText);

		Format(hudText, sizeof(hudText), "Kills: %d\nDeaths: %d\nMoney: $%d", player.Kills, player.Deaths, player.Money);
		SetHudTextParams(0.015, -0.80, 1.0, 0, 212, 89, 255, 0);
		ShowHudText(client, -1, hudText);
	}
	return Plugin_Continue;
}

public Action Timer_CalculateUptime(Handle timer) {
	_serverUptime++;
	return Plugin_Continue;
}

public Action Timer_LoyalityCheck(Handle timer, any client) {
	if(IsClientConnected(client) && IsClientInGame(client)) {
		Player player = Player(client);
		player.Money += 200;

		CPrintToChat(client, "{purple}%s{gold} You've received {green}$200{gold} as a loyality check for playing the server!", _chatPrefix);

		SQL_Save(client);
	}
	return Plugin_Continue;
}

//Generic 1 second timer for anything random
public Action Timer_Listener(Handle timer, any client) {
	if(IsClientConnected(client) && IsClientInGame(client)) {
		Player player = Player(client);
		
		if(player.Model == 0) {
			if(!IsValidModel(client)) {				
				int randomModel = GetRandomInt(0, sizeof(_standardModels));
				SetEntityModel(client, _standardModels[randomModel]);
				CPrintToChat(client, "{purple}%s{gold} Model not valid, fixing...", _chatPrefix);
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_PlayerSpawn(Handle timer, any client) {
	Player player = Player(client);
	
	GivePlayerItem(client, "weapon_357");
	GivePlayerItem(client, "weapon_crossbow");
	SetEntityHealth(client, 100);
	SetEntityModel(client, _customModels[player.Model]);
	return Plugin_Handled;
}

//* REGIONEND TIMERS *//






public void IncreaseDeaths(int client) {
	Player player = Player(client);
	player.Deaths++;
}

public void IncreaseKills(int client) {
	Player player = Player(client);
	player.Kills++;
}

public int CalculateMoneyReward(int client, char[] weapon) {
	int killValue = 0;

	//Get value based on weapon
	if(StrEqual(weapon, "crowbar") || StrEqual(weapon, "stunstick")) {
		killValue = GetRandomInt(20, 30);
	}
	else if(StrEqual(weapon, "357") || StrEqual(weapon, "crossbow_bolt")) {
		killValue = GetRandomInt(40, 50);
	}
	else if(StrEqual(weapon, "ar2") || StrEqual(weapon, "smg1") || StrEqual(weapon, "shotgun")) {
		killValue = GetRandomInt(10, 20);
	}
	else if(StrEqual(weapon, "grenade_frag") || StrEqual(weapon, "rpg_missile") || StrEqual(weapon, "slam") || StrEqual(weapon, "combine_ball") || StrEqual(weapon, "smg1_grenade")) {
		killValue = GetRandomInt(10, 20); 
	}
	else if(StrEqual(weapon, "physics")) {
		killValue = GetRandomInt(60, 70);
	}
	else if (StrEqual(weapon, "pistol")) {
		killValue = GetRandomInt(40, 50);
	}
	else {
		killValue = GetRandomInt(10, 20);
	}

	//Update player model
	Player player = Player(client);
	player.Money += killValue;

	return killValue;
}

public bool IsValidModel(int client) {
	char currentModel[50];

	GetClientModel(client, currentModel, sizeof(currentModel));

	for(int i = 0; i < sizeof(_standardModels); i++) {
		if(StrEqual(currentModel, _standardModels[i])) {
			return true;
		}
	}

	return false;
}

stock int GetServerUptime() {
	return _serverUptime;
}

stock bool BitToBool(int val) {
	if(val == 0) {
		return false;
	}
	else {
		return true;
	}
}

stock int BoolToBit(bool val) {
	if(val) {
		return 1;
	}
	else {
		return 0;
	}
}