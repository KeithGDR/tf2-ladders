#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

ConVar convar_Enabled;
ConVar convar_LadderType;
ConVar convar_Sounds;

int g_DelaySound[MAXPLAYERS + 1];
bool g_IsRight[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[TF2] Ladders",
	author = "Drixevel, Partial by Moosehead",
	description = "Implements easy to use and functional ladders in Team Fortress 2.",
	version = "1.0.0",
	url = "https://drixevel.dev/"
};

public void OnPluginStart() {
	CreateConVar("sm_tf2_ladders_version", "1.0.0", "Version control for this plugin.", FCVAR_DONTRECORD);
	convar_Enabled = CreateConVar("sm_tf2_ladders_enabled", "1", "Should this plugin be enabled or disabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_LadderType = CreateConVar("sm_tf2_ladders_type", "1", "Which functionality should the ladders use?\n(0 = water-based, 1 = manual calculating)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Sounds = CreateConVar("sm_tf2_ladders_sounds", "1", "Should sounds play when going up a ladder?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig();

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "trigger_multiple")) != -1) {
		OnTriggerSpawnPost(entity);
	}
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (StrEqual(classname, "trigger_multiple")) {
		SDKHook(entity, SDKHook_SpawnPost, OnTriggerSpawnPost);
	}
}

public void OnTriggerSpawnPost(int entity) {
	char name[64];
	GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));

	if (StrEqual(name, "ladder")) {
		SDKHook(entity, SDKHook_StartTouch, OnLadderStartTouch);
		SDKHook(entity, SDKHook_Touch, OnLadderTouch);
		SDKHook(entity, SDKHook_EndTouch, OnLadderEndTouch);
	}
}

public Action OnLadderStartTouch(int entity, int other) {
	if (!convar_Enabled.BoolValue) {
		return Plugin_Continue;
	}

	if (other < 1 || other > MaxClients) {
		return Plugin_Continue;
	}

	if (convar_LadderType.IntValue == 0) {
		SetEntityMoveType(other, MOVETYPE_LADDER);
		TF2_AddCondition(other, TFCond_SwimmingNoEffects);
	}

	return Plugin_Continue;
}

public Action OnLadderTouch(int entity, int other) {
	if (!convar_Enabled.BoolValue) {
		return Plugin_Continue;
	}

	if (other < 1 || other > MaxClients) {
		return Plugin_Continue;
	}

	if (convar_LadderType.IntValue == 1) {
		MoveOnLadder(other);
	}

	if (convar_LadderType.IntValue == 0) {
		PlayClimbSound(other);
	}

	return Plugin_Continue;
}

public Action OnLadderEndTouch(int entity, int other) {
	if (!convar_Enabled.BoolValue) {
		return Plugin_Continue;
	}

	if (other < 1 || other > MaxClients) {
		return Plugin_Continue;
	}

	if (convar_LadderType.IntValue == 0) {
		SetEntityMoveType(other, MOVETYPE_ISOMETRIC);
		TF2_RemoveCondition(other, TFCond_SwimmingNoEffects);
	}

	return Plugin_Continue;
}

void MoveOnLadder(int client)
{
	float speed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	int buttons = GetClientButtons(client);

	float origin[3];
	GetClientAbsOrigin(client, origin);

	float latest;
	bool movingUp = (origin[2] > latest);
	latest = origin[2];

	float angles[3];
	GetClientEyeAngles(client, angles);

	float velocity[3];

	if (buttons & IN_FORWARD || buttons & IN_JUMP) {
		velocity[0] = speed * Cosine(DegToRad(angles[1]));
		velocity[1] = speed * Sine(DegToRad(angles[1]));
		velocity[2] = -1 * speed * Sine(DegToRad(angles[0]));
		
		if (!movingUp && angles[0] < -25.0 && velocity[2] > 0 && velocity[2] < 250.0) {
			velocity[2] = 251.0;
		}
		
		PlayClimbSound(client);
	} else if(buttons & IN_MOVELEFT) {
		velocity[0] = speed * Cosine(DegToRad(angles[1] + 45));
		velocity[1] = speed * Sine(DegToRad(angles[1] + 45));
		velocity[2] = -1 * speed * Sine(DegToRad(angles[0]));
		
		PlayClimbSound(client);
	} else if(buttons & IN_MOVERIGHT) {
		velocity[0] = speed * Cosine(DegToRad(angles[1] - 45));
		velocity[1] = speed * Sine(DegToRad(angles[1] - 45));
		velocity[2] = -1 * speed * Sine(DegToRad(angles[0]));
		
		PlayClimbSound(client);
	} else if(buttons & IN_BACK) {
		velocity[0] = -1 * speed * Cosine(DegToRad(angles[1]));
		velocity[1] = -1 * speed * Sine(DegToRad(angles[1]));
		velocity[2] = speed * Sine(DegToRad(angles[0]));

		PlayClimbSound(client);
	} else {
		velocity[0] = 0.0;
		velocity[1] = 0.0;
		velocity[2] = 0.0;
	}

	TeleportEntity(client, origin, NULL_VECTOR, velocity);
}

void PlayClimbSound(int client) {
	if (!convar_Sounds.BoolValue) {
		return;
	}

	if (g_DelaySound[client] > GetTime()) {
		return;
	}

	g_DelaySound[client] = GetTime() + 1;

	EmitGameSoundToClient(client, g_IsRight[client] ? "Ladder.StepRight" : "Ladder.StepLeft");
	g_IsRight[client] = !g_IsRight[client];
}

public void OnClientDisconnect_Post(int client) {
	g_DelaySound[client] = false;
	g_IsRight[client] = false;
}