#include <sourcemod>
#include <colorlib>
#pragma newdecls required

public Plugin myinfo =
{
    name = "Show Online Vips",
    author = "Ilusion9",
    description = "Show online vips by groups",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

#define MAX_GROUPS		65
enum struct GroupInfo
{
	char name[64];
	int flag;
}

GroupInfo g_Groups[MAX_GROUPS];
int g_GroupsArrayLength;

public void OnPluginStart()
{
	LoadTranslations("admins_vips_online.phrases");
	RegConsoleCmd("sm_vips", Command_Vips, "Show online vips by groups");
}

public void OnConfigsExecuted()
{
	g_GroupsArrayLength = 0;
	
	char path[PLATFORM_MAX_PATH];	
	BuildPath(Path_SM, path, sizeof(path), "configs/admins_vips_online.cfg");
	KeyValues kv = new KeyValues("Groups"); 
	
	if (!kv.ImportFromFile(path))
	{
		delete kv;
		LogError("The configuration file could not be read.");
		return;
	}
	
	GroupInfo group;
	AdminFlag flag;
	
	if (!kv.JumpToKey("VIP Groups"))
	{
		delete kv;
		LogError("The configuration file is corrupt (\"VIP Groups\" section could not be found).");
		return;
	}
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetSectionName(group.name, sizeof(GroupInfo::name));
			char value[2];
			kv.GetString(NULL_STRING, value, sizeof(value));
			
			if (!FindFlagByChar(value[0], flag))
			{
				LogError("Invalid flag specified for group: %s", group.name);
				continue;
			}
			
			group.flag = FlagToBit(flag);
			g_Groups[g_GroupsArrayLength] = group;
			g_GroupsArrayLength++;
			
		} while (kv.GotoNextKey(false));
	}
	
	delete kv;
}

public Action Command_Vips(int client, int args)
{
	if (!g_GroupsArrayLength)
	{
		return Plugin_Handled;
	}
	
	bool membersOnline = false;
	int groupCount[MAX_GROUPS];
	int groupMembers[MAX_GROUPS][MAXPLAYERS + 1];
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (!IsClientInGame(player) || IsFakeClient(player))
		{
			continue;
		}
		
		for (int groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
		{	
			if (!CheckCommandAccess(player, "", g_Groups[groupIndex].flag, true))
			{
				continue;
			}
			
			membersOnline = true;
			groupMembers[groupIndex][groupCount[groupIndex]] = player;
			groupCount[groupIndex]++;
			break;
		}
	}
	
	if (!membersOnline)
	{
		CReplyToCommand(client, "%t", "No Vips Online");
		return Plugin_Handled;
	}
	
	for (int groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
	{
		if (groupCount[groupIndex])
		{
			int msgLength;
			char name[33], buffer[256];
			
			Format(buffer, sizeof(buffer), "%s", g_Groups[groupIndex].name);
			msgLength = strlen(buffer);
			
			for (int index = 0; index < groupCount[groupIndex]; index++)
			{
				GetClientName(groupMembers[groupIndex][index], name, sizeof(name));
				msgLength += strlen(name) + 2;
				
				if (msgLength > 192)
				{
					CReplyToCommand(client, "%s", buffer);
					Format(buffer, sizeof(buffer), "%s:", g_Groups[groupIndex].name);
					msgLength += strlen(buffer);
				}
				
				Format(buffer, sizeof(buffer), "%s%s %s", buffer, index ? "," : "", name);
			}
			
			CReplyToCommand(client, "%s", buffer);
		}
	}
	
	return Plugin_Handled;
}
