local SeasonPassService = {}


local Services=require(game.ReplicatedStorage.CoreModules.Services)
local Network = Services:GetService("Network")
local DataService = Services:GetService("DataService")

local PetsModule = Services:GetService("PetsModule")
local ItemsModule = Services:GetService("ItemsModule")
local SeasonPassModule = Services:GetService("SeasonPassModule")
local BoostsModule
local EggsModule 

SeasonPassService.Settings = {
	Enabled = true,
}

local Rewards = SeasonPassModule.Rewards
local Quests = SeasonPassModule.Quests
local Started = SeasonPassModule.SeasonStarted

local QuestsPerCycle = SeasonPassModule.PerQuestCycle

--function CalculateTotalWeight()
--	local totalWeight = 0
--	for _, data in pairs(CrateItems) do
--		totalWeight = totalWeight + (data.Chance)
--	end
--	return totalWeight
--end
--function ChooseItem()
--	local TotalWeight= CalculateTotalWeight()

--	local function ChooseRandomItem()
--		local RNG = Random.new() -- Create a new RNG system
--		local CurrentWeight = 0 -- initialize weight that will be added incrementally
--		local RandomWeight = RNG:NextNumber(CurrentWeight, TotalWeight) -- get random weight, starting from 0 - TotalWeight

--		for i, Data in CrateItems do -- loop through the Items
--			CurrentWeight += Data.Chance or 1 -- add up currentWeight by Item Weight

--			if CurrentWeight < RandomWeight then -- if currentWeight is not more than random weight, then go back and repeat the loop
--				continue
--			end

--			return i
--		end
--	end

--	return ChooseRandomItem()
--end

--function SeasonPassService:GetRandom()
--	return ChooseItem()
--end

local CrateDB = {}

function SeasonPassService:SeasonRestart(Player, Payed)
	if true then
		return
	end
	local PlayerData = DataService:GetPlayerData(Player)
	local SPD = PlayerData.SeasonPassData
	local GemPrice = SeasonPassModule.ResetCost

	if not (SPD.SeasonLevel >= table.maxn(Rewards)) then
		return
	end

	if not Payed and PlayerData.Gems < GemPrice then
		return
	end

	if not Payed then
		PlayerData.Gems -= GemPrice
		DataService:SendUpdateSignal(Player, "Gems")
	end

	SPD.SeasonLevel = 0
	SPD.Claimed = {
		["Free"] = {},
		["Premium"] = {},
	}
	Network:FireClient(Player,"Notify", "Bottom",  "Successfully Restarted!", 4.5, Color3.new(0.0235294, 1, 0.00784314), "rbxassetid://18126220883")
	SeasonPassService:AwardExp(Player, 0) 
end

--function SeasonPassService:OpenCrate(Player)
--	if true then
--		return
--	end
--	if not self.Settings.Enabled then
--		return
--	end
	
--	local PlayerData = DataService:GetPlayerData(Player)
--	local SPD = PlayerData.SeasonPassData
--	--print("Open Requested")
--	if CrateDB[Player.UserId] then
--		return warn("Db already")
--	end

--	if PlayerData.SeasonPassData.Keys <= 0 then
--		return warn("No Key")
--	end

--	CrateDB[Player.UserId] = true
--	PlayerData.SeasonPassData.Keys -= 1

--	--local Items = {}

--	--for i = 1, 1000_000 do
--	--	local ChosenItem = CrateItems[ChooseItem()].Name

--	--	if not Items[ChosenItem] then
--	--		Items[ChosenItem] = 1
--	--	else
--	--		Items[ChosenItem] += 1
--	--		end

--	--end

--	----print(Items)

--	-- Testing odds up here

--	local ChosenItem = false--ChooseItem()

--	task.delay(10, function()
--		if Player then
--			local ItemInfo = CrateItems[ChosenItem]
--			local Name = ItemInfo.Name

--			if PetsModule[Name] then
--				DataService:AddPet(Player, Name)
--			elseif ItemsModule.Items[Name] then
--				DataService:AddItem(Player, Name, nil, nil, ItemInfo.Amount, true)
--				--DataService:AddItem(Player, Name, nil,nil, ItemInfo.Amount,true)
--			elseif Name == "Event Egg" then
--				PlayerData.EventEggData.Owned += ItemInfo.Amount
--				DataService:SendUpdateSignal(Player, "EventEggData")
--			else
--				DataService:AddCurrency(Player, Name, ItemInfo.Amount)
--			end
--		end

--		CrateDB[Player.UserId] = nil
--	end)
--	DataService:SendUpdateSignal(Player, "SeasonPassData")
--	Network:FireClient(Player, "AnimateSeasonCrate", ChosenItem)
--end

function SeasonPassService:ClaimTier(Player, TierType, Index)
	
	if not self.Settings.Enabled then
		return
	end
	
	local PlayerData = DataService:GetPlayerData(Player)
	local SPD = PlayerData.SeasonPassData

	-- checks if its a valid tier type or if the player has claimed it
	if not SPD.Claimed[TierType] or SPD.Claimed[TierType][tostring(Index)] then
		return warn(1)
	end 

	if not (SPD.SeasonLevel >= Index) then
		return warn(2)
	end

	if TierType == "Premium" and not SPD.OwnsPremium then
		return warn(3)
	end

	SPD.Claimed[TierType][tostring(Index)] = true

	local RewardInfo = SeasonPassService:GetSeasonInfo(Index)[TierType]


	if PetsModule[RewardInfo.Name] then
		for i = 1, RewardInfo.Amount or 1 do
			DataService:AddPet(Player, RewardInfo.Name, RewardInfo.Tier, RewardInfo.SecondTier)
		end
	elseif ItemsModule.Items[RewardInfo.Name] then
		DataService:AddItem(Player, RewardInfo.Name, RewardInfo.Tier, RewardInfo.SecondTier, RewardInfo.Amount)

	elseif PlayerData[RewardInfo.Name] and typeof(RewardInfo.Amount) == typeof(PlayerData[RewardInfo.Name]) then
		DataService:AddCurrency(Player, RewardInfo.Name, RewardInfo.Amount)
	end


	DataService:SendUpdateSignal(Player, "SeasonPassData")
	Network:FireClient(Player, "UpdateTierInfo", Index)
end

function SeasonPassService:GetNextSeasonInfo(Player)
	
	if not self.Settings.Enabled then
		return
	end	

	if game:GetService("RunService"):IsClient() then
		Network = Services:GetService("Network")
	end

	local PlayerData = DataService and DataService:GetPlayerData(Player) or Network:Call("GetClientPlayerData")

	if not PlayerData then
		return warn("Cant get playerdata for season pass")
	end

	local SPD = PlayerData.SeasonPassData
	local NextInfo = Rewards[SPD.SeasonLevel + 1]
	if not NextInfo then
		return
	end

	return NextInfo
end

function SeasonPassService:GetSeasonInfo(Index)
	return Rewards[Index]
end


function SeasonPassService:GetCurrentSeasonInfo(Player)
	if not self.Settings.Enabled then
		return
	end
	if game:GetService("RunService"):IsClient() then
		Network = Services:GetService("Network")
	end

	local PlayerData = DataService and DataService:GetPlayerData(Player) or Network:Call("GetClientPlayerData")

	if not PlayerData then
		return warn("Cant get playerdata for season pass")
	end

	local SPD = PlayerData.SeasonPassData
	local NextInfo = Rewards[SPD.SeasonLevel]
	if not NextInfo then
		return warn("Max Level")
	end

	return NextInfo
end


local LblUpDb = {}
function SeasonPassService:AwardExp(Player, Amount)
	if not self.Settings.Enabled then
		return
	end
	
	BoostsModule = BoostsModule or Services:GetService("BoostsModule")

	local PlayerData = DataService:GetPlayerData(Player)
	local Boosts = BoostsModule:GetPlayerBoosts(Player)
	local SPD = PlayerData.SeasonPassData



	SPD.SeasonExp += Amount * (Boosts["Season Pass Multi"] or 1)

	if not LblUpDb[Player.UserId] then
		LblUpDb[Player.UserId] = true
		while true do
			local ExpNeeded = SeasonPassService:GetExpNeeded(Player)
			local Max = ExpNeeded == "Max"
			
			if Max then
				ExpNeeded = 1000
			end
			
			if SPD.SeasonExp < ExpNeeded then
				break
			end
			SPD.SeasonExp -= ExpNeeded
			if not Max then
				SPD.SeasonLevel += 1
			else
				-- reward "max level" stuff
				DataService:AddItem(Player, "Champions Gift")
				
				if math.random(1,100) <= Boosts["Additional Champ Gift"] then
					DataService:AddItem(Player, "Champions Gift")
					Network:FireClient(Player,"Notify", "Bottom",  "You got an additional Champion Gift!", 4.5, Color3.new(0.0235294, 1, 0.00784314), "rbxassetid://18126220883")
				end
				
			end
			Network:FireClient(Player,"Notify", "Bottom",  "Season Level Up!", 4.5, Color3.new(0.0235294, 1, 0.00784314), "rbxassetid://18126220883")
			DataService:SendUpdateSignal(Player, "SeasonPassData")
			Network:FireClient(Player, "UpdateTierInfo", SPD.SeasonLevel)

		end
		LblUpDb[Player.UserId] = nil
	end

	DataService:SendUpdateSignal(Player, "SeasonPassData")

end


function SeasonPassService:QuestProgressed(Player, Amount, QuestType, SecondaryInfo)
	if not self.Settings.Enabled then
		return
	end
	local PlayerData = DataService:GetPlayerData(Player)
	local SPD = PlayerData.SeasonPassData

	local Clone = table.clone(SPD.Quests)

	local Changes = false

	for Index, QuestData in pairs(Clone) do
		local QuestInfo = Quests[QuestData.Index]

		if QuestInfo.QuestType ~= QuestType then
			continue
		end

		if not QuestData["RandomInfo"] then
			if SecondaryInfo and QuestInfo.SecondaryInfo and QuestInfo.SecondaryInfo ~= SecondaryInfo then
				continue
			end
		else
			if QuestData.RandomInfo ~= SecondaryInfo then
				continue
			end
		end
		
		
		Changes = true
		QuestData.Progress += Amount
		local AmountNeeded = QuestData.AmountNeeded or QuestInfo.Amount
		local ExpGiven = QuestData.ExpGiven or QuestInfo.ExpGain
		if QuestData.Progress >= AmountNeeded then
			table.remove(Clone, Index)
			SeasonPassService:AwardExp(Player, ExpGiven)
		end

	end

	SPD.Quests = Clone


	if not Changes then
		return
	end

	DataService:SendUpdateSignal(Player, "SeasonPassData")

end

function SeasonPassService:GiveQuests(Player)
	if not self.Settings.Enabled then
		return
	end
	EggsModule = EggsModule or Services:GetService("EggsModule")
	local PlayerData = DataService:GetPlayerData(Player)
	local SPD = PlayerData.SeasonPassData

	local TimeSeasonStarted = os.time() - Started

	local Cycles = math.floor(TimeSeasonStarted/(60*60*24)) + 1


	Cycles = Cycles - #SPD.QuestCycles

	for i = 1, Cycles do
		table.insert(SPD.QuestCycles, true)
	end

	for i = 1, Cycles * QuestsPerCycle do
		local RandomIndex = math.random(1, #Quests)
		local RandomQuest = Quests[RandomIndex]
		
		
		
		local TemplateTable = {
			["Index"] = RandomIndex,
			["Progress"] = 0,
		}

		if RandomQuest["RandomObjective"] then
			if RandomQuest["QuestType"] == "Pet" then
				local AllPets = {}
				local SelectedPet = nil
				for i, x in EggsModule do
					if typeof(x) == "table" and x["Cost"] then -- egg
						
						if x.Locked then
							continue
						end
						
						for Name, _ in pairs(x.Chances) do
							table.insert(AllPets, Name)
						end
					end
				end
				repeat wait()
					SelectedPet = AllPets[math.random(1, #AllPets)]
					
				until PetsModule[SelectedPet]
				
				local Rarity = PetsModule[SelectedPet].Rarity
				local AmountNeededTable = {
					["Common"] = 30,
					["Uncommon"] = 25,
					["Rare"] = 20,
					["Epic"] = 15,
					["Legendary"] = 10,
					["Godly"] = 5,
					["Event"] = 30,
					["Huge"] = 1,
				}
				
				local AmountNeeded = AmountNeededTable[Rarity] or 5
				TemplateTable["RandomInfo"] = SelectedPet
				TemplateTable["AmountNeeded"] = AmountNeeded
				TemplateTable["ExpGiven"] = math.floor(500/(AmountNeeded/2))
				
			elseif RandomQuest["QuestType"] == "Special Egg" then
				local AllEggs = {}
				local SelectedPet = nil
				for i, x in EggsModule do
					if typeof(x) == "table" and x["Cost"] then -- egg

						if x.Locked then
							continue
						end
						
						table.insert(AllEggs, i)

					
					end
				end
				SelectedPet = AllEggs[math.random(1, #AllEggs)]
				local AmountNeeded = math.random(200,1500)
				
				AmountNeeded = math.ceil(AmountNeeded/50) * 50
				
				TemplateTable["RandomInfo"] = SelectedPet
				TemplateTable["AmountNeeded"] = AmountNeeded
				TemplateTable["ExpGiven"] = AmountNeeded/5
			end
		end

		table.insert(SPD.Quests, TemplateTable)

	end
	DataService:SendUpdateSignal(Player, "SeasonPassData")
end

function SeasonPassService:GetExpNeeded(Player)
	if not  SeasonPassService:GetNextSeasonInfo(Player) then
		return "Max"
	end
	return SeasonPassService:GetNextSeasonInfo(Player).Exp
end


return SeasonPassService
