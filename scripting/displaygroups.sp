#include <sourcemod>
#pragma newdecls required

public Plugin myinfo =
{
    name = "Display groups",
    author = "Ilusion9",
    description = "Display admins and vips by groups",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

enum struct GroupInfo
{
	char name[65];
	int flag;
}

GroupInfo g_Groups[65];
int g_GroupsLength;
int g_VipGroupIndex;

public void OnPluginStart()
{
	RegConsoleCmd("sm_groups", Command_Groups);
}

public void OnConfigsExecuted()
{
	g_GroupsLength = 0;
	g_VipGroupIndex = 0;
	
	char path[PLATFORM_MAX_PATH];	
	BuildPath(Path_SM, path, sizeof(path), "configs/displaygroups.cfg");
	KeyValues kv = new KeyValues("Groups"); 
	
	if (!kv.ImportFromFile(path))
	{
		delete kv;
		LogError("The configuration file could not be read.");
		return;
	}
	
	GroupInfo group;
	AdminFlag flag;
	
	if (!kv.JumpToKey("Admin Groups"))
	{
		delete kv;
		LogError("The configuration file is corrupt (\"Admin Groups\" section could not be found).");
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
			g_Groups[g_GroupsLength] = group;
			g_GroupsLength++;
			
		} while (kv.GotoNextKey(false));
	}
	
	g_VipGroupIndex = g_GroupsLength;
	kv.Rewind();
	
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
			g_Groups[g_GroupsLength] = group;
			g_GroupsLength++;
			
		} while (kv.GotoNextKey(false));
	}
	
	delete kv;
}

public Action Command_Groups(int client, int args)
{
	bool adminDisplayed[MAXPLAYERS + 1], vipDisplayed[MAXPLAYERS + 1];
	for (int groupIndex = 0; groupIndex < g_VipGroupIndex; groupIndex++)
	{
		char buffer[256];
		bool memberFound = false;
		Format(buffer, sizeof(buffer), "%s:", g_Groups[groupIndex].name);
		
		for (int clientEnt = 1; clientEnt <= MaxClients; clientEnt++)
		{
			if (IsClientInGame(clientEnt))
			{
				if (!adminDisplayed[clientEnt])
				{
					if (CheckCommandAccess(clientEnt, "", g_Groups[groupIndex].flag, true))
					{
						memberFound = true;
						adminDisplayed[clientEnt] = true;
						Format(buffer, sizeof(buffer), "%s %N,", buffer, clientEnt);
					}
				}
			}
		}
		
		if (memberFound)
		{
			buffer[strlen(buffer) - 1] = 0;
			ReplyToCommand(client, "[SM] %s", buffer);
		}
	}
	
	for (int groupIndex = g_VipGroupIndex; groupIndex < g_GroupsLength; groupIndex++)
	{
		char buffer[256];
		bool memberFound = false;
		Format(buffer, sizeof(buffer), "%s:", g_Groups[groupIndex].name);
		
		for (int clientEnt = 1; clientEnt <= MaxClients; clientEnt++)
		{
			if (IsClientInGame(clientEnt))
			{
				if (!vipDisplayed[clientEnt])
				{
					if (CheckCommandAccess(clientEnt, "", g_Groups[groupIndex].flag, true))
					{
						memberFound = true;
						vipDisplayed[clientEnt] = true;
						Format(buffer, sizeof(buffer), "%s %N,", buffer, clientEnt);
					}
				}
			}
		}
		
		if (memberFound)
		{
			buffer[strlen(buffer) - 1] = 0;
			ReplyToCommand(client, "[SM] %s", buffer);
		}
	}
	
	return Plugin_Handled;
}
