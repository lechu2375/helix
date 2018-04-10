
local PANEL = {}

function PANEL:Init()
	self:SetSize(ScrW() * 0.45, ScrH() * 0.65)
	self:SetTitle("")
	self:MakePopup()
	self:Center()

	local header = self:Add("DPanel")
	header:SetTall(34)
	header:Dock(TOP)

	self.vendorName = header:Add("DLabel")
	self.vendorName:Dock(LEFT)
	self.vendorName:SetWide(self:GetWide() * 0.5 - 7)
	self.vendorName:SetText("John Doe")
	self.vendorName:SetTextInset(4, 0)
	self.vendorName:SetTextColor(color_white)
	self.vendorName:SetFont("ixMediumFont")

	self.ourName = header:Add("DLabel")
	self.ourName:Dock(RIGHT)
	self.ourName:SetWide(self:GetWide() * 0.5 - 7)
	self.ourName:SetText(L"you".." ("..ix.currency.Get(LocalPlayer():GetChar():GetMoney())..")")
	self.ourName:SetTextInset(0, 0)
	self.ourName:SetTextColor(color_white)
	self.ourName:SetFont("ixMediumFont")

	local footer = self:Add("DPanel")
	footer:SetTall(34)
	footer:Dock(BOTTOM)
	footer:SetDrawBackground(false)

	self.vendorSell = footer:Add("DButton")
	self.vendorSell:SetFont("ixMediumFont")
	self.vendorSell:SetWide(self.vendorName:GetWide())
	self.vendorSell:Dock(LEFT)
	self.vendorSell:SetContentAlignment(5)
	-- The text says purchase but the vendor is selling it to us.
	self.vendorSell:SetText(L"purchase")
	self.vendorSell:SetTextColor(color_white)
	self.vendorSell.DoClick = function(this)
		if (IsValid(self.activeSell)) then
			netstream.Start("vendorTrade", self.activeSell.item)
		end
	end

	self.vendorBuy = footer:Add("DButton")
	self.vendorBuy:SetFont("ixMediumFont")
	self.vendorBuy:SetWide(self.ourName:GetWide())
	self.vendorBuy:Dock(RIGHT)
	self.vendorBuy:SetContentAlignment(5)
	self.vendorBuy:SetText(L"sell")
	self.vendorBuy:SetTextColor(color_white)
	self.vendorBuy.DoClick = function(this)
		if (IsValid(self.activeBuy)) then
			netstream.Start("vendorTrade", self.activeBuy.item, true)
		end
	end

	self.selling = self:Add("DScrollPanel")
	self.selling:SetWide(self:GetWide() * 0.5 - 7)
	self.selling:Dock(LEFT)
	self.selling:DockMargin(0, 4, 0, 4)
	self.selling:SetDrawBackground(true)

	self.sellingItems = self.selling:Add("DListLayout")
	self.sellingItems:SetSize(self.selling:GetSize())
	self.sellingItems:DockPadding(0, 0, 0, 4)
	self.sellingItems:SetTall(ScrH())

	self.buying = self:Add("DScrollPanel")
	self.buying:SetWide(self:GetWide() * 0.5 - 7)
	self.buying:Dock(RIGHT)
	self.buying:DockMargin(0, 4, 0, 4)
	self.buying:SetDrawBackground(true)

	self.buyingItems = self.buying:Add("DListLayout")
	self.buyingItems:SetSize(self.buying:GetSize())
	self.buyingItems:DockPadding(0, 0, 0, 4)

	self.sellingList = {}
	self.buyingList = {}
end

function PANEL:addItem(uniqueID, listID)
	local entity = self.entity
	local items = entity.items
	local data = items[uniqueID]

	if ((!listID or listID == "selling") and !IsValid(self.sellingList[uniqueID])
	and ix.item.list[uniqueID]) then
		if (data and data[VENDOR_MODE] and data[VENDOR_MODE] != VENDOR_BUYONLY) then
			local item = self.sellingItems:Add("ixVendorItem")
			item:Setup(uniqueID)

			self.sellingList[uniqueID] = item
			self.sellingItems:InvalidateLayout()
		end
	end

	if ((!listID or listID == "buying") and !IsValid(self.buyingList[uniqueID])
	and LocalPlayer():GetCharacter():GetInventory():HasItem(uniqueID)) then
		if (data and data[VENDOR_MODE] and data[VENDOR_MODE] != VENDOR_SELLONLY) then
			local item = self.buyingItems:Add("ixVendorItem")
			item:Setup(uniqueID)
			item.isLocal = true

			self.buyingList[uniqueID] = item
			self.buyingItems:InvalidateLayout()
		end
	end
end

function PANEL:removeItem(uniqueID, listID)
	if (!listID or listID == "selling") then
		if (IsValid(self.sellingList[uniqueID])) then
			self.sellingList[uniqueID]:Remove()
			self.sellingItems:InvalidateLayout()
		end
	end

	if (!listID or listID == "buying") then
		if (IsValid(self.buyingList[uniqueID])) then
			self.buyingList[uniqueID]:Remove()
			self.buyingItems:InvalidateLayout()
		end
	end
end

function PANEL:Setup(entity)
	self.entity = entity
	self:SetTitle(entity:GetNetVar("name", ""))
	self.vendorName:SetText(entity:GetNetVar("name", "")..(entity.money and " ("..entity.money..")" or ""))

	for k, _ in SortedPairs(entity.items) do
		self:addItem(k, "selling")
	end

	for _, v in SortedPairs(LocalPlayer():GetChar():GetInv():GetItems()) do
		self:addItem(v.uniqueID, "buying")
	end
end

function PANEL:OnRemove()
	netstream.Start("vendorExit")

	if (IsValid(ix.gui.vendorEditor)) then
		ix.gui.vendorEditor:Remove()
	end
end

function PANEL:Think()
	local entity = self.entity

	if (!IsValid(entity)) then
		self:Remove()

		return
	end

	if ((self.nextUpdate or 0) < CurTime()) then
		self:SetTitle(self.entity:GetNetVar("name"))
		self.vendorName:SetText(entity:GetNetVar("name", "")..(entity.money and " ("..ix.currency.Get(entity.money)..")" or ""))
		self.ourName:SetText(L"you".." ("..ix.currency.Get(LocalPlayer():GetChar():GetMoney())..")")

		self.nextUpdate = CurTime() + 0.25
	end
end

function PANEL:OnItemSelected(panel)
	local price = self.entity:GetPrice(panel.item, panel.isLocal)

	if (panel.isLocal) then
		self.vendorBuy:SetText(L"sell".." ("..ix.currency.Get(price)..")")
	else
		self.vendorSell:SetText(L"purchase".." ("..ix.currency.Get(price)..")")
	end
end

vgui.Register("ixVendor", PANEL, "DFrame")

PANEL = {}

function PANEL:Init()
	self:SetTall(36)
	self:DockMargin(4, 4, 4, 0)

	self.icon = self:Add("SpawnIcon")
	self.icon:SetPos(2, 2)
	self.icon:SetSize(32, 32)
	self.icon:SetModel("models/error.mdl")

	self.name = self:Add("DLabel")
	self.name:Dock(FILL)
	self.name:DockMargin(42, 0, 0, 0)
	self.name:SetFont("ixChatFont")
	self.name:SetTextColor(color_white)
	self.name:SetExpensiveShadow(1, Color(0, 0, 0, 200))

	self.click = self:Add("DButton")
	self.click:Dock(FILL)
	self.click:SetText("")
	self.click.Paint = function() end
	self.click.DoClick = function(this)
		if (self.isLocal) then
			ix.gui.vendor.activeBuy = self
		else
			ix.gui.vendor.activeSell = self
		end

		ix.gui.vendor:OnItemSelected(self)
	end
end

function PANEL:SetCallback(callback)
	self.click.DoClick = function(this)
		callback()
		self.selected = true
	end
end

function PANEL:Setup(uniqueID)
	local item = ix.item.list[uniqueID]

	if (item) then
		self.item = uniqueID
		self.icon:SetModel(item.model, item.skin or 0)
		self.name:SetText(L(item.name))
		self.itemName = L(item.name)
	end
end

function PANEL:Think()
	if ((self.nextUpdate or 0) < CurTime()) then
		local name = self.itemName
		local entity = ix.gui.vendor.entity

		if (entity) then
			if (self.isLocal) then
				local count = LocalPlayer():GetChar():GetInv():GetItemCount(self.item)

				if (count == 0) then
					self:Remove()
				end

				name = name.." ("..count..")"
			elseif (entity.items[self.item] and entity.items[self.item][VENDOR_MAXSTOCK]) then
				name = name.." ("..entity.items[self.item][VENDOR_STOCK].."/"..entity.items[self.item][VENDOR_MAXSTOCK]..")"
			end
		end

		self.name:SetText(name)
		self.nextUpdate = CurTime() + 0.1
	end
end

function PANEL:Paint(w, h)
	if (ix.gui.vendor.activeBuy == self or ix.gui.vendor.activeSell == self) then
		surface.SetDrawColor(ix.config.Get("color"))
	else
		surface.SetDrawColor(0, 0, 0, 100)
	end

	surface.DrawRect(0, 0, w, h)
end

vgui.Register("ixVendorItem", PANEL, "DPanel")
