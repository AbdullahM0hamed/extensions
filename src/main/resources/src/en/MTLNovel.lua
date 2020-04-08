-- {"id":573,"version":"1.0.0","author":"Doomsdayrs","repo":""}

local baseURL = "https://www.mtlnovel.com"
local settings = { 0 }

---@type fun(table, string): string
local qs = Require("url").querystring
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
	local d = GETDocument(url):selectFirst("article.post")
	local n = NovelInfo()
	n:setTitle(d:selectFirst("h1.entry-title"):text())
	n:setImageURL(d:selectFirst("amp-img.main-tmb"):selectFirst("amp-img.main-tmb"):attr("src"))
	n:setDescription(table.concat(map(d:selectFirst("div.desc"):select("p"), text)))

	local details = d:selectFirst("table.info"):select("tr")

	n:setAlternativeTitles({ getDetail(details:get(0)), getDetail(details:get(1)) })

	local sta = getDetailE(details:get(2)):selectFirst("a"):text()
	n:setStatus(NovelStatus(sta == "Completed" and 1 or sta == "Ongoing" and 0 or 3))

	n:setAuthors({ getDetail(details:get(3)) })
	n:setGenres(map(getDetailE(details:get(6)):select("a"), text))
	n:setTags(map(getDetailE(details:get(10)):select("a"), text))

	d = GETDocument(url .. "/chapter-list/")

	local chapterBox = d:selectFirst("div.ch-list")
	if chapterBox ~= nil then
		local chapters = chapterBox:select("a")
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
	return table.concat(map(d:selectFirst("div.post-content"):select(({ [0] = "p.en", "p.cn" })[settings[1]]), text), "\n")
end

local filters = {
	DropdownFilter("Order by", { "Date", "Name", "Rating", "Views" }),
	DropdownFilter("Order", { "Descending", "Ascending" }),
	DropdownFilter("Status", { "All", "Completed", "Ongoing" })
}

return {
	id = 573,
	name = "MTLNovel",
	baseURL = baseURL,
	imageURL = baseURL .. "/wp-content/themes/mtlnovel/images/logo32.png",
	hasSearch = false,
	listings = {
		Listing("Novel List", filters, true, function(data, page)
			local d = GETDocument(baseURL .. "/novel-list/" ..
					"?orderby=" .. ({ [0] = "date", [1] = "name", [2] = "rating", [3] = "view" })[data[1]] ..
					"&order=" .. ({ [0] = "desc", [1] = "asc" })[data[2]] ..
					"&status=" .. ({ [0] = "all", [1] = "completed", [2] = "ongoing" })[data[3]] ..
					"&pg=" .. tostring(page or 1))
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
	search = function() end,
	settings = { DropdownFilter("Language", { "English", "Chinese" }) },
	updateSetting = function(id, value) settings[id] = value end
}
