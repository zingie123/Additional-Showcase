local SeasonPassManager = {}

local Services=require(game.ReplicatedStorage.CoreModules.Services)
local HttpService=game:GetService('HttpService')
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")

local SFXService = Services:GetService("SFXService")
local Network=Services:GetService("Network")
local GuiService=Services:GetService("GuiService")
local ImageService=Services:GetService("ImageService")
local PetsModule=Services:GetService("PetsModule")
local ItemsModule=Services:GetService("ItemsModule")
local RarityService=Services:GetService("RarityService")
local ShopManager = Services:GetService("ShopManager")
local DescriptionManager = Services:GetService("DescriptionManager")
local SeasonPassModule = Services:GetService("SeasonPassModule")
local SeasonPassService = Services:GetService("SeasonPassService")
local PetInventory = Services:GetService("PetInventory")

local Player = game.Players.LocalPlayer

local Settings = SeasonPassService.Settings

local Template = script.Template
local QuestTemplate = script.QuestTemplate
local MainFrame = GuiService.Frames.SeasonPass
local GemPrice = SeasonPassModule.ResetCost


local Started = false

SeasonPassManager.HoldingUpdate=false



function SeasonPassManager:Update(Index)
	local Frame = MainFrame.Rewards:FindFirstChild(Index)
	local RewardInfo = SeasonPassModule.Rewards[Index]
	
	if not Frame or not RewardInfo then
		return warn("Wat")
	end
	
	local PlayerData = Network:Call("GetClientPlayerData")
	local SPD = PlayerData.SeasonPassData
	
	if SPD.OwnsPremium then
		Frame.Premium.Star.Visible = false
	else
		Frame.Premium.Star.Visible = true
	end
	
	if SPD.SeasonLevel < Index then
		Frame.Locked.Visible = true	
	else
		Frame.Locked.Visible = false
	end
	
	-- Free
	local FreeFrame = Frame.Free
	local FreeInfo = RewardInfo.Free
	FreeFrame.Icon.Image = ImageService(FreeInfo.ImageName or FreeInfo.Name)
	FreeFrame.ItemName.Text = FreeInfo.Name
	FreeFrame.Amount.Text = FreeInfo.Amount
	
	if PetsModule[FreeInfo.Name] then
		PetInventory:ApplyEffect(FreeFrame.Icon, FreeInfo.Tier)
		PetInventory:ApplyEffect(FreeFrame.Icon, FreeInfo.SecondTier)
		FreeFrame.Amount.Visible = false
	end
	if PetsModule[FreeInfo.Name] then
		local FullName = FreeInfo.Tier .. "_" .. FreeInfo.SecondTier .. "_" .. FreeInfo.Name
		
		DescriptionManager:CreateDefaultPetDescription(FreeFrame, FullName)
	elseif ItemsModule.Items[FreeInfo.Name] then
		DescriptionManager:CreateDefaultItemDescription(FreeFrame, "Normal_Normal_"..FreeInfo.Name)
	else
		DescriptionManager:CreateDescription(FreeFrame, {["Text"] = FreeInfo.Name, ["DescriptionType"] = "ShortDescription"})
	end
	
	if SPD.Claimed.Free[tostring(Index)] then
		FreeFrame.Claim.Visible = false
	else
		FreeFrame.Claim.Visible = true
	end
	-- Premium
	local PremiumFrame = Frame.Premium
	local PremiumInfo = RewardInfo.Premium

	PremiumFrame.Icon.Image = ImageService(PremiumInfo.ImageName or PremiumInfo.Name)
	PremiumFrame.ItemName.Text = PremiumInfo.Name
	PremiumFrame.Amount.Text = PremiumInfo.Amount
	
	if PetsModule[PremiumInfo.Name] then
		PremiumFrame.Amount.Visible = false
		PetInventory:ApplyEffect(PremiumFrame.Icon, PremiumInfo.Tier)
		PetInventory:ApplyEffect(PremiumFrame.Icon, PremiumInfo.SecondTier)

	end
	if PetsModule[PremiumInfo.Name] then
		local FullName = PremiumInfo.Tier .. "_" .. PremiumInfo.SecondTier .. "_" .. PremiumInfo.Name

		DescriptionManager:CreateDefaultPetDescription(PremiumFrame, FullName)
	elseif ItemsModule.Items[PremiumInfo.Name] then
		DescriptionManager:CreateDefaultItemDescription(PremiumFrame, "Normal_Normal_"..PremiumInfo.Name)
	else
		DescriptionManager:CreateDescription(PremiumFrame, {["Text"] = PremiumInfo.Name, ["DescriptionType"] = "ShortDescription"})
	end
	
	if SPD.Claimed.Premium[tostring(Index)] then
		PremiumFrame.Claim.Visible = false
	else
		PremiumFrame.Claim.Visible = true
	end
end

function UpdateAll()
	for i = 1, #SeasonPassModule.Rewards do
		SeasonPassManager:Update(i)
	end
end

function SeasonPassManager:GenerateQuests()
	local PlayerData = Network:Call("GetClientPlayerData")
	local SPD = PlayerData.SeasonPassData
	
	for _, frame in pairs(MainFrame.Quests:GetChildren()) do
		if frame:IsA("Frame") and frame.Name ~= "Blank" then
			frame:Destroy()
		end
	end
	
	for Index, Info in pairs(SPD.Quests) do
		local FrameName =  math.floor((Index+1)/2)
		local QuestInfo = SeasonPassModule.Quests[Info.Index]
		
		local Frame = MainFrame.Quests:FindFirstChild(FrameName)
		
		if not Frame then
			local Clone = QuestTemplate:Clone()
			Clone.Name = FrameName
			Clone.Parent = MainFrame.Quests
			Clone["1"].Name = Index
			Clone["2"].Name = Index+1
			Frame = Clone
			if table.maxn(SPD.Quests) == Index then
				Frame[Index+1].Visible = false
			end
			
		end
		
		local ToUpdate = Frame[Index]
		local AmountNeeded = Info.AmountNeeded or QuestInfo.Amount
		local Percent = Info.Progress / AmountNeeded
		local ExpGiven = Info.ExpGiven or QuestInfo.ExpGain

		local DescriptionText = QuestInfo.Description
		
		if DescriptionText:find("PETNAME") then
			local Text = Info["RandomInfo"]
			if AmountNeeded > 1 then
				Text = Text .. "s"
			end
			DescriptionText = DescriptionText:gsub("PETNAME", Text)
		end
		
		if DescriptionText:find("AMOUNT") then
			DescriptionText = DescriptionText:gsub("AMOUNT", AmountNeeded)
		end
		
		ToUpdate.Title.Text = QuestInfo.Title
		ToUpdate.Description.Text = DescriptionText
		ToUpdate.Main.Star.Amount.Text =ExpGiven
		
		
		Percent = Percent > 1 and 1 or Percent
		ToUpdate.Icon.Image = ImageService(QuestInfo.ImageName)
		ToUpdate.Bar.Main.Size = UDim2.new(Percent,0,1,0)

		ToUpdate.Bar.Progress.Text = GuiService:AddCommas(Info.Progress) .. "/" .. GuiService:AddCommas(AmountNeeded)

	end
	
end

function SeasonPassManager:UpdateLabels()
	local PlayerData = Network:Call("GetClientPlayerData")
	local SPD = PlayerData.SeasonPassData
	
	local ExpNeeded = SeasonPassService:GetExpNeeded(Player)
	
	local Max = ExpNeeded == "Max"
	
	if Max then
		MainFrame.Star["+1Level"].Visible = false
		MainFrame["Skip 10 Tiers"].Visible = false
		MainFrame["Skip Tier"].Visible = false
		
		ExpNeeded = 1000
	end
	
	local ExpDisplay =  GuiService:AddCommas(SPD.SeasonExp)
	
	if ExpNeeded then
		ExpDisplay = ExpDisplay .. "/" .. GuiService:AddCommas(ExpNeeded)
	end
	
	MainFrame.Star.Level.Text = SPD.SeasonLevel
	MainFrame.Star.Bar.Amount.Text = ExpDisplay
	
	local Percent = ExpNeeded and SPD.SeasonExp/ExpNeeded or 1
	
	if Percent >= 1 then
		-- TODO player has enough exp and should level up, tell the server
		Percent = 1
	end
	MainFrame.Star.Bar.Inner.Size = UDim2.new(Percent,0,1,0)
	
	--MainFrame.Keys.Label.TextLabel.Text = SPD.Keys
	
	
	--MainFrame.CrateFrame.Left.Button.TextLabel.Text = "Roll (" .. SPD.Keys .. ")"
	
	--if SPD.Keys > 0 then
	--	GuiService:SetButtonColor(MainFrame.CrateFrame.Left.Button, "Positive")
	--else
	--	GuiService:SetButtonColor(MainFrame.CrateFrame.Left.Button, "Grey")
	--end
	
	if SPD.OwnsPremium then
		MainFrame.Start.Premium.Premium.Visible = false
		MainFrame.Start.Premium.Activated.Visible = true
		MainFrame["Premium Pass"].Visible = false
		MainFrame["Premium Bundle"].Visible = false
	else
		MainFrame.Start.Premium.Premium.Visible = true
		MainFrame.Start.Premium.Activated.Visible = false
		MainFrame["Premium Pass"].Visible = true
		MainFrame["Premium Bundle"].Visible = true
	end
	
end
function SeasonPassManager:Generate()
	for Index, Info in pairs(SeasonPassModule.Rewards) do
		local Clone = Template:Clone()
		
		Clone.Parent = MainFrame.Rewards
		Clone.Name = Index
		SeasonPassManager:Update(Index)
		
		GuiService:CreateButton(Clone.Free.Claim.Button, function()
			Network:FireServer("ClaimBattlePass", "Free", Index)
		end)
		
		GuiService:CreateButton(Clone.Premium.Claim.Button, function()
			Network:FireServer("ClaimBattlePass", "Premium", Index)
		end)
		
		ShopManager:CreatePurchase(Clone.Locked.Skip.Button, "Skip Tier", MainFrame.Name)
		
		
		
	end
	
end



function SetButtons()
	
	DescriptionManager:CreateDefaultItemDescription(MainFrame.Rewards.Bonus.Premium.Icon, "Normal_Normal_Champions Gift")
	
	ShopManager:CreatePurchase(MainFrame.Start.Premium.Premium.Button, "Premium Pass", MainFrame.Name)
	ShopManager:CreatePurchase(MainFrame["Skip 10 Tiers"].Buy.Button, "Skip 10 Tiers", MainFrame.Name)
	ShopManager:CreatePurchase(MainFrame["Skip Tier"].Buy.Button, "Skip Tier", MainFrame.Name)
	ShopManager:CreatePurchase(MainFrame["Premium Pass"].Buy.Button, "Premium Pass", MainFrame.Name)
	ShopManager:CreatePurchase(MainFrame["Premium Bundle"].Buy.Button, "Premium Bundle", MainFrame.Name)

	ShopManager:CreatePurchase(MainFrame.Star["+1Level"].Button, "Skip Tier", MainFrame.Name)

	GuiService:CreateButton(MainFrame.RewardsButton.Button,function()
		MainFrame.CrateFrame.Visible = false

		MainFrame.Star.Visible = true
		MainFrame.Rewards.Visible = true
		MainFrame.Start.Visible = true

		MainFrame.Quests.Visible = false
	end)
	
	GuiService:CreateButton(MainFrame.QuestsButton.Button,function()
		MainFrame.CrateFrame.Visible = false

		MainFrame.Star.Visible = true
		MainFrame.Rewards.Visible = false
		MainFrame.Start.Visible = false

		MainFrame.Quests.Visible = true
	end)
	
	GuiService:CreateButton(MainFrame.CrateButton.Button,function()
		MainFrame.CrateFrame.Visible = true
		
		MainFrame.Star.Visible = false
		MainFrame.Rewards.Visible = false
		MainFrame.Start.Visible = false
		
		MainFrame.Quests.Visible = false
		
	end)
end


function SeasonPassManager:Initialize()
	if Started then
		return
	end
	
	if not Settings.Enabled  then
		return 
	end
	
	Network:Bind("BoughtPassSkip", function()
		UpdateAll()
	end)
	
	Network:Bind("UpdateTierInfo", function(index)
		SeasonPassManager:Update(index)
	end)
	
	MainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if MainFrame.Visible and SeasonPassManager.HoldingUpdate then
			SeasonPassManager.HoldingUpdate=false
			SeasonPassManager:GenerateQuests()
			SeasonPassManager:UpdateLabels()
			
		end
	end)
	
	Started = true
	SeasonPassManager:Generate()
	SeasonPassManager:UpdateLabels()
	SeasonPassManager:GenerateQuests()
	SetButtons()
end

return SeasonPassManager
