-- Bagis urunleri: fiyatlar Roblox'tan okunur ve onbellege alinir.
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(script.Parent.Config)

local Products = {}
local priceCache = {}

function Products.GetPrice(productId)
	if priceCache[productId] then
		return priceCache[productId]
	end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId, Enum.InfoType.Product)
	if ok and info and info.PriceInRobux then
		priceCache[productId] = info.PriceInRobux
		return info.PriceInRobux
	end
	return nil
end

-- Config'teki gecerli (ID > 0 ve fiyati okunabilen) urunler
function Products.Catalog()
	local items = {}
	for _, product in ipairs(Config.PRODUCTS) do
		local price = product.Id > 0 and Products.GetPrice(product.Id)
		if price then
			table.insert(items, { Id = product.Id, Name = product.Name, Price = price })
		end
	end
	return items
end

function Products.IsValid(productId)
	for _, product in ipairs(Config.PRODUCTS) do
		if product.Id > 0 and product.Id == productId then
			return true
		end
	end
	return false
end

return Products
