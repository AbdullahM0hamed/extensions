-- {"id":573,"ver":"1.0.2","libVer":"1.0.0","author":"Doomsdayrs","dep":["url>=1.0.0"]}

local baseURL = "https://www.mtlnovel.com"
local ajaxURL = baseURL .. "/wp-admin/admin-ajax.php"
local settings = { [1] = 0 }

local ORDER_BYS_INT = { [0] = "date",[1] = "name",[2] = "rating",[3] = "view" }
local ORDER_BYS_KEY = 102

local ORDERS_INT = { [0] = "desc",[1] = "asc" }
local ORDERS_KEY = 103

local STATUES_INT = { [0] = "all",[1] = "completed",[2] = "ongoing" }
local STATUSES_KEY = 104

---@type fun(table, string): string
local qs = Require("url").querystring

local POST = Require("dkjson").POST
local decode = Require("dkjson").decode

---@param v Element | Elements
local function text(v)
	return v:text()
end

---@param element Element
---@return Elements
local function getDetailE(element)
	return element:select("td"):get(2)
end

---@param element Element
---@return string
local function getDetail(element)
	return text(getDetailE(element))
end

--- @param novelURL string @URL of novel
--- @return NovelInfo
local function parseNovel(novelURL)
	local url = baseURL .. "/" .. novelURL
	local document = GETDocument(url):selectFirst("article.post")
	local n = NovelInfo()
	n:setTitle(document:selectFirst("h1.entry-title"):text())
	n:setImageURL(document:selectFirst("amp-img.main-tmb"):selectFirst("amp-img.main-tmb"):attr("src"))
	n:setDescription(table.concat(map(document:selectFirst("div.desc"):select("p"), text)))

	local details = document:selectFirst("table.info"):select("tr")
	local details2 = document:select("table.info"):get(1):select("tr")

	n:setAlternativeTitles({ getDetail(details:get(0)),getDetail(details:get(1)) })

	local sta = getDetailE(details:get(2)):selectFirst("a"):text()
	n:setStatus(NovelStatus(sta == "Completed" and 1 or sta == "Ongoing" and 0 or 3))

	n:setAuthors({ getDetail(details:get(3)) })
	n:setGenres(map(getDetailE(details2:get(0)):select("a"), text))
	n:setTags(map(getDetailE(details2:get(5)):select("a"), text))

	document = GETDocument(url .. "/chapter-list/")

	local chapterBox = document:selectFirst("div.ch-list")
	if chapterBox ~= nil then
		local chapters = chapterBox:select("a.ch-link")
		local count = chapters:size()
		local chaptersList = AsList(map(chapters, function(v)
			local c = NovelChapter()
			c:setTitle(v:text():gsub("<strong>", ""):gsub("</strong>", " "))
			c:setLink(v:attr("href"):match(baseURL .. "/(.+)/?$"))
			c:setOrder(count)
			count = count - 1
			return c
		end))
		Reverse(chaptersList)
		n:setChapters(chaptersList)
	end
	return n
end

--- @param chapterURL string @url of the chapter
--- @return string @of chapter
local function getPassage(chapterURL)
	local d = GETDocument(baseURL .. "/" .. chapterURL)
	--({ [0] = "p.en", [1] = "p.cn" })[settings[1]]
	return table.concat(map(d:selectFirst("div.par"):select("p"), text), "\n")
end

---@return table @Novel array list
local function search(filters)
    data = POST(ajaxURL, nil, RequestBody(qs({ action = "autosuggest", q = filters[QUERY] }), MediaType("application/x-www-form-urlencoded")))

    decoded = decode(data)
    results_response = decoded.items[0].results

    local results = {}
    for index in results_response do
        novel = Novel()
        novel:setTitle(results_response[index].title)
        novel:setLink(results_response[index].permalink)
        novel:setImageURL(results_response[index].thumbnail)
        results[index] = novel
    end

    return results
end
         
return {
	id = 573,
	name = "MTLNovel",
	baseURL = baseURL,
	imageURL = "https://github.com/shosetsuorg/extensions/raw/dev/src/main/resources/icons/MTLNovel.png",
	listings = {
		Listing("Novel List", true, function(data)
			local d = GETDocument(baseURL .. "/novel-list/" ..
					"?orderby=" .. ORDER_BYS_INT[data[ORDER_BYS_KEY]] ..
					"&order=" .. ORDERS_INT[data[ORDERS_KEY]] ..
					"&status=" .. STATUES_INT[data[STATUSES_KEY]] ..
					"&pg=" .. data[PAGE])
			return map(d:select("div.box.wide"), function(v)
				local lis = Novel()
				lis:setImageURL(v:selectFirst("amp-img.list-img"):selectFirst("amp-img.list-img"):attr("src"))
				local title = v:selectFirst("a.list-title")
				lis:setLink(title:attr("href"):match(baseURL .. "/(.+)/"))
				lis:setTitle(title:attr("aria-label"))
				return lis
			end)
		end)
	},
	getPassage = getPassage,
	parseNovel = parseNovel,
    search = search,
	--settings = {
		--  DropdownFilter(1, "Language", { "English", "Chinese" })
	--},
	searchFilters = {
		DropdownFilter(ORDER_BYS_KEY, "Order by", { "Date","Name","Rating","Views" }),
		DropdownFilter(ORDERS_KEY, "Order", { "Descending","Ascending" }),
		DropdownFilter(STATUSES_KEY, "Status", { "All","Completed","Ongoing" })
	},
	--updateSetting = function(id, value)
	--	settings[id] = value
	--end
}
