RR_VERSION = "Raid Restore v1.08";

---------------------
-- Saved Variables --
---------------------

SavedTemplates = {};    -- Master list of raids
RR_Options = {};

TemplateFilter = "nax";

----------------------
-- Global Variables --
----------------------
RaidRestore = {};

Debug_Mode = "off";
Output_Stats = "on";
TypeMenuParentButton = nil;
RaidMenuParentButton = nil;

--------------------
-- Defined Values --
--------------------

RR_CLASSES = {"warrior", "rogue", "warlock", "mage", "hunter", "shaman", "druid", "priest"};
RR_FILTERS = {"aq", "bwl", "mc", "nax"};

RR_NAME     = 1;
RR_CLASS    = 2;
RR_ROLE     = 3;
RR_SUBGROUP = 4;
RR_START    = 5;
RR_LOCKED   = 6;
RR_INDEX    = 7;

AL_TYPE     = 1;
AL_ID1      = 2;
AL_ID2      = 3;

RaidRestore.DefaultOptions = function()
	if (not RR_Options["Filter"]) then
		RR_Options["Filter"] = "bwl";
	end
	
	if (not RR_Options["ToggleVisible"]) then
		RR_Options["ToggleVisible"] = 0;
	end
	
	if (not RR_Options["SelectVisible"]) then
		RR_Options["SelectVisible"] = 1;
	end
end

RaidRestore.GetOption = function(strOption)
	return RR_Options[strOption];
end

RaidRestore.SetOption = function(strOption, value)
	RR_Options[strOption] = value;
end

-------------------------
-- Struct Initializers --
-------------------------

function InitializeTemplate(pTemplate)
	-- Make 8 groups of 5 slots
	for nGroup = 1, 8, 1 do
		pTemplate[nGroup] = {};
		for nSlot = 1, 5, 1 do
			pTemplate[nGroup][nSlot] = {};
		end
	end
end

function CreateTarget(pTemplate, pTarget)
	for nGroup = 1, 8, 1 do
		for nSlot = 1, 5, 1 do
			pTarget[nGroup][nSlot][RR_NAME] = pTemplate[nGroup][nSlot][RR_NAME];
			pTarget[nGroup][nSlot][RR_CLASS] = pTemplate[nGroup][nSlot][RR_CLASS];
			pTarget[nGroup][nSlot][RR_ROLE] = GetClassRole(pTemplate[nGroup][nSlot][RR_CLASS]);
			
			if (pTarget[nGroup][nSlot][RR_NAME] == nil) then
				pTarget[nGroup][nSlot][RR_NAME] = "";
			end
			
			if (pTarget[nGroup][nSlot][RR_CLASS] == nil) then
				pTarget[nGroup][nSlot][RR_CLASS] = "";
			end
			
			if (pTarget[nGroup][nSlot][RR_ROLE] == nil) then
				pTarget[nGroup][nSlot][RR_ROLE] = "";
			end
		end
	end
end

function InitializeRaid(pRaid)
	for nGroup = 1, 8, 1 do
		pRaid[nGroup] = {};
		for nSlot = 1, 5, 1 do
			pRaid[nGroup][nSlot] = {};
			pRaid[nGroup][nSlot][RR_NAME] = "";
			pRaid[nGroup][nSlot][RR_CLASS] = "";
			pRaid[nGroup][nSlot][RR_ROLE] = "";
			pRaid[nGroup][nSlot][RR_SUBGROUP] = nGroup;
			pRaid[nGroup][nSlot][RR_START] = 0;
			pRaid[nGroup][nSlot][RR_LOCKED] = 0;
			pRaid[nGroup][nSlot][RR_INDEX] = 0;
		end
	end
end

function GetRaidInfo(pRaid)
	local nMembers = GetNumRaidMembers();
	local nCounts = {0, 0, 0, 0, 0, 0, 0, 0};
	local nSubgroup = 0;
	local pIndexes = {};

	-- Get raid information
	for nIndex = 1, nMembers, 1 do		
		strName, nRank, nGroup, nLevel, strClass = GetRaidRosterInfo(nIndex);
		
		if (strName ~= nil) then
			nCounts[nGroup] = nCounts[nGroup] + 1;
			pRaid[nGroup][nCounts[nGroup]][RR_NAME] = string.lower(strName);
			pRaid[nGroup][nCounts[nGroup]][RR_CLASS] = string.lower(strClass);
			pRaid[nGroup][nCounts[nGroup]][RR_ROLE] = GetClassRole(string.lower(strClass)) or "";
			pRaid[nGroup][nCounts[nGroup]][RR_START] = nGroup;
			pRaid[nGroup][nCounts[nGroup]][RR_LOCKED] = 0;
			pRaid[nGroup][nCounts[nGroup]][RR_INDEX] = nIndex;
		end
	end
end

---------------------------
-- Action List Functions --
---------------------------

function AddAction(pActionList, type, id1, id2)
	local nNext = table.getn(pActionList) + 1;
	
	if (Debug_Mode == "on" or Debug_Mode == "dual") then
		if (type == "swap") then
			Trace(" - preparing " .. type .. ": " .. UnitName("raid" .. id1) .. " with " .. UnitName("raid" .. id2));
		else
			Trace(" - preparing " .. type .. ": " .. UnitName("raid" .. id1) .. " to " .. id2);
		end
	end
	
	pActionList[nNext] = {};
	pActionList[nNext][AL_TYPE] = type;
	pActionList[nNext][AL_ID1] = id1;
	pActionList[nNext][AL_ID2] = id2;
end

function InvertActions(pActionList, id1, id2)
	local nCount = table.getn(pActionList);
	
	if (Debug_Mode == "on" or Debug_Mode == "dual") then
		Trace(" - inverting: " .. UnitName("raid" .. id1) .. " and " .. UnitName("raid" .. id2));
	end
	
	for nIndex = 1, nCount, 1 do
		if (pActionList[nIndex][AL_TYPE] == "swap") then		
			if (pActionList[nIndex][AL_ID1] == id1) then
				pActionList[nIndex][AL_ID1] = id2;
			elseif (pActionList[nIndex][AL_ID1] == id2) then
				pActionList[nIndex][AL_ID1] = id1;
			end
			
			if (pActionList[nIndex][AL_ID2] == id1) then
				pActionList[nIndex][AL_ID2] = id2;
			elseif (pActionList[nIndex][AL_ID2] == id2) then
				pActionList[nIndex][AL_ID2] = id1;
			end
		end
	end
end

function ExecuteActions(pActionList)
	local nCount = table.getn(pActionList);
	
	for nIndex = 1, nCount, 1 do
		if (pActionList[nIndex][AL_TYPE] == "swap") then
			SwapRaidSubgroupEx(pActionList[nIndex][AL_ID1], pActionList[nIndex][AL_ID2]);
		elseif (pActionList[nIndex][AL_TYPE] == "move") then
			SetRaidSubgroupEx(pActionList[nIndex][AL_ID1], pActionList[nIndex][AL_ID2]);
		end
	end
end

------------------------
-- Raid Restore Logic --
------------------------

function SetRaidSubgroupEx(nIndex1, nGroup)
	if (Debug_Mode == "on" or Debug_Mode == "dual") then
		Trace(" - moving " .. UnitName("raid" .. nIndex1) .. " to " .. nGroup);
	end
	
	if (Debug_Mode == "off" or Debug_Mode == "dual") then
		SetRaidSubgroup(nIndex1, nGroup);
	end
end

function SwapRaidSubgroupEx(nIndex1, nIndex2)
	if (Debug_Mode == "on" or Debug_Mode == "dual") then
		Trace(" - swapping " .. UnitName("raid" .. nIndex1) .. " with " .. UnitName("raid" .. nIndex2));
	end
	
	if (Debug_Mode == "off" or Debug_Mode == "dual") then
		SwapRaidSubgroup(nIndex1, nIndex2);
	end
end

function ClearSlot(pSlot)
	pSlot[RR_NAME] = "";
	pSlot[RR_CLASS] = "";
	pSlot[RR_ROLE] = "";
end

function SwapRaidSlots(pTargetSlot, pSrcSlot, pDestSlot)
	-- Swap player info
	pSrcSlot[RR_NAME],pDestSlot[RR_NAME] = pDestSlot[RR_NAME],pSrcSlot[RR_NAME];
	pSrcSlot[RR_CLASS],pDestSlot[RR_CLASS] = pDestSlot[RR_CLASS],pSrcSlot[RR_CLASS];
	pSrcSlot[RR_ROLE],pDestSlot[RR_ROLE] = pDestSlot[RR_ROLE],pSrcSlot[RR_ROLE];
	pSrcSlot[RR_INDEX],pDestSlot[RR_INDEX] = pDestSlot[RR_INDEX],pSrcSlot[RR_INDEX];
	pSrcSlot[RR_START],pDestSlot[RR_START] = pDestSlot[RR_START],pSrcSlot[RR_START];
	
	-- Lock player
	pSrcSlot[RR_LOCKED] = 1;
	
	-- Clear target entry
	ClearSlot(pTargetSlot);
end

function MatchSlot(pSlot1, pSlot2, nField)
	if (pSlot1[nField] ~= nil and pSlot2[nField] ~= nil and pSlot1[nField] ~= "" and pSlot2[nField] ~= "") then
		if (pSlot1[nField] == pSlot2[nField]) then
			return true;
		end
	end
	
	return false;
end

function AttemptPlayerLock(pRaidGroup, pTargetSlot, nField)	
	for nSlot = 1, 5, 1 do
		if (pRaidGroup[nSlot][RR_LOCKED] == 0 and MatchSlot(pRaidGroup[nSlot], pTargetSlot, nField) == true) then
			ClearSlot(pTargetSlot);
			pRaidGroup[nSlot][RR_LOCKED] = 1;
			return;
		end
	end
end

function AttemptTargetLock(pTargetGroup, pRaidSlot, nField)	
	for nSlot = 1, 5, 1 do
		if (MatchSlot(pTargetGroup[nSlot], pRaidSlot, nField) == true) then
			ClearSlot(pTargetGroup[nSlot]);
			pRaidSlot[RR_LOCKED] = 1;
			return;
		end
	end
end

function FindUnlockedInGroup(pRaidGroup, pDestSlot, pTargetGroup, nField)
	-- Return slot that will lock first
	for nSlot = 1, 5, 1 do
		if (pRaidGroup[nSlot][RR_LOCKED] == 0) then
			for nTarget = 1, 5, 1 do
				if (MatchSlot(pTargetGroup[nTarget], pRaidGroup[nSlot], nField) == true) then
					return pRaidGroup[nSlot];
				end
			end
		end
	end

	-- Return empty slot next
	for nSlot = 1, 5, 1 do
		if (pRaidGroup[nSlot][RR_LOCKED] == 0 and pRaidGroup[nSlot][nField] == "") then
			return pRaidGroup[nSlot];
		end
	end
	
	-- Return any unlocked
	for nSlot = 1, 5, 1 do
		if (pRaidGroup[nSlot][RR_LOCKED] == 0) then
			return pRaidGroup[nSlot];
		end
	end
end

function FindUnlockedInRaid(pRaid, pTargetSlot, nField)
	for nGroup = 1, 8, 1 do
		for nSlot = 1, 5, 1 do
			if (pRaid[nGroup][nSlot][RR_LOCKED] == 0 and MatchSlot(pRaid[nGroup][nSlot], pTargetSlot, nField) == true) then
				return pRaid[nGroup][nSlot];
			end
		end
	end
end

function ShowMissing(pTarget)
	local MissingClasses = {};
	
	for nType,strType in pairs(RR_CLASSES) do
		MissingClasses[strType] = 0;
	end
	
	for nGroup = 1, 8, 1 do
		for nSlot = 1, 5, 1 do				
			if (pTarget[nGroup][nSlot][RR_CLASS] ~= "") then
				MissingClasses[pTarget[nGroup][nSlot][RR_CLASS]] = MissingClasses[pTarget[nGroup][nSlot][RR_CLASS]] + 1;
			end
		end
	end
	
	for nType,strType in pairs(RR_CLASSES) do
		if (MissingClasses[strType] > 0) then
			Trace(" - missing " .. MissingClasses[strType] .. " " .. strType);
		end
	end
end

function RestoreRaid(strName)
	if (strName == nil or strName == "") then
		return;
	else
		strName = string.lower(strName);
	end
	
	if (SavedTemplates[strName] == nil) then
		Print("|cFFFFFF00RAID NOT FOUND: (" .. strName .. ")");
		return;
	end

	local pTarget = {};
	local pSubRaid = {};
	local pCurrentRaid = {};
	local pActionList = {};

	-- Setup target template structure
	InitializeTemplate(pTarget);
	CreateTarget(SavedTemplates[strName], pTarget);

	-- Setup subraid structure
	InitializeRaid(pSubRaid);
	GetRaidInfo(pSubRaid);

	Trace(" ");
	Trace("|cFFFFFF00Generating target template...");
	
	-- Generate ideal target setup
	for nField = RR_NAME, RR_ROLE, 1 do
		-- Lock people already in position
		for nGroup = 1, 8, 1 do
			for nSlot = 1, 5, 1 do
				AttemptPlayerLock(pSubRaid[nGroup], pTarget[nGroup][nSlot], nField);
			end
		end
		
		-- Position people
		for nGroup = 1, 8, 1 do
			for nSlot = 1, 5, 1 do				
				-- Find players to swap
				local pDestSlot = FindUnlockedInRaid(pSubRaid, pTarget[nGroup][nSlot], nField);
				
				if (pDestSlot ~= nil) then
					local pSrcSlot = FindUnlockedInGroup(pSubRaid[nGroup], pDestSlot, pTarget[pDestSlot[RR_SUBGROUP]], nField);
					
					if (pSrcSlot ~= nil) then
						SwapRaidSlots(pTarget[nGroup][nSlot], pSrcSlot, pDestSlot);
						
						if (pSrcSlot[nField] ~= "") then
							AttemptTargetLock(pTarget[pDestSlot[RR_SUBGROUP]], pDestSlot, nField);
						end
					end
				end
			end
		end
	end

	-- Output missing classes
	ShowMissing(pTarget);
		
	Trace(" ");
	Trace("|cFFFFFF00Building swap list...");

	-- Setup current raid structure
	InitializeRaid(pCurrentRaid);
	GetRaidInfo(pCurrentRaid);
	
	-- Lock people already in position
	for nGroup = 1, 8, 1 do
		for nSlot = 1, 5, 1 do
			AttemptPlayerLock(pCurrentRaid[nGroup], pSubRaid[nGroup][nSlot], RR_NAME);
		end
	end
	
	-- Position people
	for nGroup = 1, 8, 1 do
		for nSlot = 1, 5, 1 do
			-- Find players to swap
			local pDestSlot = FindUnlockedInRaid(pCurrentRaid, pSubRaid[nGroup][nSlot], RR_NAME);

			if (pDestSlot ~= nil) then
				local pSrcSlot = FindUnlockedInGroup(pCurrentRaid[nGroup], pDestSlot, pSubRaid[pDestSlot[RR_SUBGROUP]], RR_NAME);
				
				if (pSrcSlot ~= nil) then
					if (pSrcSlot[RR_START] == pDestSlot[RR_START]) then
						InvertActions(pActionList, pSrcSlot[RR_INDEX], pDestSlot[RR_INDEX]);
					elseif (pSrcSlot[RR_NAME] == "") then
						AddAction(pActionList, "move", pDestSlot[RR_INDEX], nGroup);
						SwapRaidSlots(pSubRaid[nGroup][nSlot], pSrcSlot, pDestSlot);
					else
						AddAction(pActionList, "swap", pSrcSlot[RR_INDEX], pDestSlot[RR_INDEX]);
						SwapRaidSlots(pSubRaid[nGroup][nSlot], pSrcSlot, pDestSlot);
						AttemptTargetLock(pSubRaid[pDestSlot[RR_SUBGROUP]], pDestSlot, RR_NAME);
					end
				end
			end
		end
	end

	Trace(" ");
	Trace("|cFFFFFF00Updating raid configuration...");

	-- Perform actual raid swaps
	ExecuteActions(pActionList);
	
	Trace(" ");
	Print("|cFFFFFF00RESTORED RAID: (" .. strName .. ")");
end

--------------------
-- Event Handlers --
--------------------

function RaidRestore_CommandHandler(msg)
	local pList = {};
	local strCommand;

	for strCommand in string.gfind(msg, "[^ ]+") do
		table.insert(pList, string.lower(strCommand))
	end

	if (table.getn(pList) == 0) then
		PrintHelp();
	elseif (pList[1] == "restore") then
		RestoreRaid(string.lower(string.sub(msg, 9)));
	elseif (pList[1] == "debug") then
		Debug_Mode = string.lower(string.sub(msg, 7));
	elseif (pList[1] == "show") then
		if (RaidRestore_MainFrame:IsVisible()) then
			RaidRestore_MainFrame:Hide();
		else
			RaidRestore_MainFrame:Show();
		end
	elseif (pList[1] == "toggle") then
		if (QuickAccess_MainFrame:IsVisible()) then
			QuickAccess_MainFrame:Hide();
			RaidRestore_ToggleCheck:SetChecked(nil);
		else
			QuickAccess_MainFrame:Show();
			RaidRestore_ToggleCheck:SetChecked(true);
		end
	elseif (pList[1] == "select") then
		if (RaidRestore_RaidSelect:IsVisible()) then
			RaidRestore_RaidSelect:Hide();
			RaidRestore_SelectCheck:SetChecked(nil);
		else
			RaidRestore_RaidSelect:Show();
			RaidRestore_SelectCheck:SetChecked(true);
		end
	elseif (pList[1] == "reset") then
		RaidRestore_MainFrame:ClearAllPoints();
		RaidRestore_MainFrame:SetPoint("CENTER", "UIParent", "CENTER");
		RaidRestore_MainFrame:Show();

		QuickAccess_MainFrame:ClearAllPoints();
		QuickAccess_MainFrame:SetPoint("CENTER", "UIParent", "CENTER");		
		QuickAccess_MainFrame:Show();
	elseif (pList[1] == "aq" or pList[1] == "bwl" or pList[1] == "mc" or pList[1] == "nax" or pList[1] == "misc") then
		RaidRestore.SetOption("Filter", pList[1]);
		SetSelectedFilter(RaidRestore.GetOption("Filter"));
	else
		PrintHelp();
	end
end

function RaidRestore_OnLoad()
	SLASH_RR1 = "/rr";
	SlashCmdList["RR"] =
		function(msg) RaidRestore_CommandHandler(msg);
		end

	this:RegisterEvent("VARIABLES_LOADED");

	Print(RR_VERSION .. " Loaded");
end

function RaidRestore_OnEvent(event)
	if (event == "VARIABLES_LOADED") then
		RaidRestore.DefaultOptions();
		
		SetSelectedFilter(RaidRestore.GetOption("Filter"));
		
		if (RaidRestore.GetOption("SelectVisible") == 1) then
			RaidRestore_RaidSelect:Show();
			RaidRestore_SelectCheck:SetChecked(true);
		end

		if (RaidRestore.GetOption("ToggleVisible") == 1) then
			QuickAccess_MainFrame:Show();
			RaidRestore_ToggleCheck:SetChecked(true);
		end
	end
end

function PrintHelp()
	Print(RR_VERSION .. " Command List");
	Print("SHOW                   (Open/Close the Raid Restore Panel)");
	Print("TOGGLE                 (Open/Close the Quick Access Panel)");
	Print("SELECT                 (Open/Close the Raid Select Panel)");
	Print("RESET                  (Reset all window positions)");
	Print("RESTORE <raid>   (Restores the specified raid)");
	Print("DEBUG [on,off,dual]   (Sets the current debugging mode)");
end

-----------------------
-- Utility Functions --
-----------------------

function Trace(msg)
	if (Debug_Mode == "on" or Debug_Mode == "dual") then
		DEFAULT_CHAT_FRAME:AddMessage(msg);
	end
end

function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg);
end

function GetClassRole(strClass)
	if (strClass ~= nil) then	
		if (strClass == "warrior" or strClass == "rogue") then
			return "melee";
		elseif (strClass == "hunter" or strClass == "mage" or strClass == "warlock") then
			return "range";
		elseif (strClass == "priest" or strClass == "shaman" or strClass == "druid") then
			return "healer";
		end
	end
end

function GetNullText(Control)
	if (Control == nil) then
		return;
	end
	
	local strText = Control:GetText();
	
	if (strText == nil or strText == "") then
		return nil;
	else
		return string.lower(strText);
	end
end

function SetNullText(Control, strText, color)
	if (Control == nil) then
		return;
	end

	if (strText == nil) then
		strText = "";
	end
	
	Control:SetText(strText);
	
	if (color == true) then
		-- Set text color to match raid class
		local color = RAID_CLASS_COLORS[string.upper(strText)];	
		
		if (color ~= nil) then
			Control:SetTextColor(color.r, color.g, color.b);
		else
			Control:SetTextColor(0.7, 0.7, 0.7);
		end
	end
end

function ClearNames()
	for i = 1, 40, 1 do
		getglobal("RaidRestore_PlayerName"..i):SetText("");
	end
end

function ClearClasses()
	for i = 1, 40, 1 do
		getglobal("RaidRestore_PlayerClass"..i):SetText("");
	end
end

-------------------------
-- Template Management --
-------------------------

function AddTemplate(Frame, strName)
	if (strName == nil or strName == "") then
		return;
	end

	strName = string.lower(strName);
	SetSelectedRaid(strName);
	UpdateTemplate(Frame, strName);
	
	Print("|cFFFFFF00ADDED RAID: (" .. strName .. ")");
end

function UpdateTemplate(Frame, strName)
	if (strName == nil or strName == "") then
		return;
	end

	strName = string.lower(strName);
	
	if (SavedTemplates[strName] == nil) then
		SavedTemplates[strName] = {};
		InitializeTemplate(SavedTemplates[strName]);
	end
	
	local pTemplate = SavedTemplates[strName];
	
	for nGroup = 1, 8, 1 do
		for nSlot = 1, 5, 1 do
			pTemplate[nGroup][nSlot][RR_NAME] = GetNullText(getglobal("RaidRestore_PlayerName"..(((nGroup-1)*5)+nSlot)));
			pTemplate[nGroup][nSlot][RR_CLASS] = GetNullText(getglobal("RaidRestore_PlayerClass"..(((nGroup-1)*5)+nSlot)));
		end
	end
end

function DeleteTemplate(strName)
	if (strName == nil or strName == "") then
		return;
	end

	strName = string.lower(strName);
	ClearNames();
	ClearClasses();
	SavedTemplates[strName] = nil;
	SetSelectedRaid("");
	
	Print("|cFFFFFF00DELETED RAID: (" .. strName .. ")");
end

function LoadTemplate(Frame, strName)
	if (strName == nil or strName == "") then
		return;
	end

	strName = string.lower(strName);
	ClearNames();
	ClearClasses();
	
	if (SavedTemplates[strName] == nil) then
		SavedTemplates[strName] = {};
		InitializeTemplate(SavedTemplates[strName]);
	end
	
	local pTemplate = SavedTemplates[strName];
	
	for nGroup = 1, 8, 1 do
		for nSlot = 1, 5, 1 do
			SetNullText(getglobal("RaidRestore_PlayerName"..(((nGroup-1)*5)+nSlot)), pTemplate[nGroup][nSlot][RR_NAME], false);
			SetNullText(getglobal("RaidRestore_PlayerClass"..(((nGroup-1)*5)+nSlot)), pTemplate[nGroup][nSlot][RR_CLASS], true);
		end
	end
end

function CaptureTemplate(Frame, strName, nField)
	if (strName == nil or strName == "") then
		return;
	end

	strName = string.lower(strName);
	local pCurrentRaid = {};

	InitializeRaid(pCurrentRaid);
	GetRaidInfo(pCurrentRaid);
	
	for nGroup,pGroup in ipairs(pCurrentRaid) do
		for nGroupSlot,pGroupSlot in ipairs(pGroup) do
			if (nField == RR_NAME) then
				SetNullText(getglobal("RaidRestore_PlayerName"..(((nGroup-1)*5)+nGroupSlot)), pGroupSlot[RR_NAME], false);
			elseif (nField == RR_CLASS) then
				SetNullText(getglobal("RaidRestore_PlayerClass"..(((nGroup-1)*5)+nGroupSlot)), pGroupSlot[RR_CLASS], true);
			end
		end
	end
end

function NormalizeTemplate(Frame)
	for nGroup = 1, 8, 1 do
		local pGroup = {};
		local pTarget = {};
		local nCount = 0;

		-- Capture frame data
		for nSlot = 1, 5, 1 do
			pGroup[nSlot] = {};
			pTarget[nSlot] = {};
			
			pGroup[nSlot][RR_NAME] = GetNullText(getglobal("RaidRestore_PlayerName"..(((nGroup-1)*5)+nSlot)));
			pGroup[nSlot][RR_CLASS] = GetNullText(getglobal("RaidRestore_PlayerClass"..(((nGroup-1)*5)+nSlot)));
		end

		-- Fill target in class order
		for nType,strType in pairs(RR_CLASSES) do
			for nSlot = 1, 5, 1 do
				if (pGroup[nSlot][RR_CLASS] ~= nil and pGroup[nSlot][RR_CLASS] == strType) then
					nCount = nCount + 1;
					pTarget[nCount][RR_NAME] = pGroup[nSlot][RR_NAME];
					pTarget[nCount][RR_CLASS] = pGroup[nSlot][RR_CLASS];
					pGroup[nSlot][RR_NAME] = nil;
					pGroup[nSlot][RR_CLASS] = nil;
				end
			end
		end
		
		-- Fill in solo names
		for nSlot = 1, 5, 1 do
			if (pGroup[nSlot][RR_NAME] ~= nil) then
				nCount = nCount + 1;
				pTarget[nCount][RR_NAME] = pGroup[nSlot][RR_NAME];
				pTarget[nCount][RR_CLASS] = pGroup[nSlot][RR_CLASS];
				pGroup[nSlot][RR_NAME] = nil;
				pGroup[nSlot][RR_CLASS] = nil;
			end
		end
			
		-- Output frame data
		for nSlot = 1, 5, 1 do
			SetNullText(getglobal("RaidRestore_PlayerName"..(((nGroup-1)*5)+nSlot)), pTarget[nSlot][RR_NAME], false);
			SetNullText(getglobal("RaidRestore_PlayerClass"..(((nGroup-1)*5)+nSlot)), pTarget[nSlot][RR_CLASS], true);
		end
	end
end

------------------------
-- Combobox Functions --
------------------------

function SetSelectedRaid(strName)
	if (strName ~= nil) then
		UIDropDownMenu_SetText(string.lower(strName), RaidRestore_TemplateList);
	end
end

function GetSelectedRaid()
	return UIDropDownMenu_GetText(RaidRestore_TemplateList);
end

function RaidRestore_TemplateList_OnLoad()
	UIDropDownMenu_Initialize(this, LoadTemplateList);
end

function RaidRestore_TemplateList_OnClick()
	SetSelectedRaid(this.value);
	LoadTemplate(RaidRestore_MainFrame, GetSelectedRaid());
end

function FilterTemplate(strTemplate)
	local strFilter = RaidRestore.GetOption("Filter");
	
	if (strFilter == nil) then
		return true;
	end
	
	if (strsub(strTemplate, 1, strlen(strFilter)) == strFilter) then
		return true;
	end

	if (strFilter == "misc") then
		for nIndex,strFilter in ipairs(RR_FILTERS) do	
			if (strsub(strTemplate, 1, strlen(strFilter)) == strFilter) then
				return nil;
			end
		end
		
		return true;
	end
end

function LoadTemplateList()
	local pList = {};
	local nIndex = 0;
	
	for strName,pTemplate in pairs(SavedTemplates) do
		if (FilterTemplate(strName)) then
			nIndex = nIndex + 1;
			pList[nIndex] = strName;
		end
	end

	-- sort it so it looks nice
	table.sort(pList);
	
	for nIndex,strName in ipairs(pList) do
		local info = {};
		info.text = strName;
		info.value = strName;
		info.func = RaidRestore_TemplateList_OnClick;
		UIDropDownMenu_AddButton(info);
	end
end

function SetSelectedFilter(strName)
	if (strName ~= nil) then
		UIDropDownMenu_SetText(string.lower(strName), RaidRestore_FilterList);
	end
end

function GetSelectedFilter()
	return UIDropDownMenu_GetText(RaidRestore_FilterList);
end

function RaidRestore_FilterList_OnLoad()
	UIDropDownMenu_Initialize(this, LoadFilterList);
end

function RaidRestore_FilterList_OnClick()
	SetSelectedFilter(this.value);
	RaidRestore.SetOption("Filter", GetSelectedFilter());
end

function LoadFilterList()
	for nIndex,strName in ipairs(RR_FILTERS) do
		local info = {};
		info.text = strName;
		info.value = strName;
		info.func = RaidRestore_FilterList_OnClick;
		UIDropDownMenu_AddButton(info);
	end

	local info = {};
	info.text = "misc";
	info.value = "misc";
	info.func = RaidRestore_FilterList_OnClick;
	UIDropDownMenu_AddButton(info);
end

function QuickAccess_FilterMenu_OnLoad()
	UIDropDownMenu_Initialize(this, LoadFilterMenuList, "MENU");
end

function QuickAccess_FilterMenu_OnClick()
	RaidRestore.SetOption("Filter", this.value);
	SetSelectedFilter(RaidRestore.GetOption("Filter"));	
end

function LoadFilterMenuList()
	for nIndex,strName in ipairs(RR_FILTERS) do
		local info = {};
		info.text = strName;
		info.value = strName;
		info.func = QuickAccess_FilterMenu_OnClick;
		UIDropDownMenu_AddButton(info);
	end

	local info = {};
	info.text = "misc";
	info.value = "misc";
	info.func = QuickAccess_FilterMenu_OnClick;
	UIDropDownMenu_AddButton(info);
end

function QuickAccess_RaidMenu_OnLoad()
	UIDropDownMenu_Initialize(this, LoadRaidList, "MENU");
end

function QuickAccess_RaidMenu_OnClick()
	if (RaidMenuParentButton == nil) then
		RestoreRaid(this.value);
	else
		SetNullText(RaidMenuParentButton, this.value, false);
	end
end

function LoadRaidList()
	local pList = {};
	local nIndex = 0;
	
	for strName,pTemplate in pairs(SavedTemplates) do
		if (FilterTemplate(strName)) then
			nIndex = nIndex + 1;
			pList[nIndex] = strName;
		end
	end

	-- sort it so it looks nice
	table.sort(pList);
	
	for nIndex,strName in ipairs(pList) do
		local info = {};
		info.text = strName;
		info.value = strName;
		info.func = QuickAccess_RaidMenu_OnClick;
		UIDropDownMenu_AddButton(info);
	end
end

function RaidRestore_TypeMenu_OnLoad()
	UIDropDownMenu_Initialize(this, LoadTypeList, "MENU");
end

function RaidRestore_TypeMenu_OnClick()
	SetNullText(TypeMenuParentButton, this.value, true);
end

function LoadTypeList()
	for nType,strType in pairs(RR_CLASSES) do
		local info = {};
		info.text = strType;
		info.value = strType;
		info.func = RaidRestore_TypeMenu_OnClick;
		UIDropDownMenu_AddButton(info);
	end
end
