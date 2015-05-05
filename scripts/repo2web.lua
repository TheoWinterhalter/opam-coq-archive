#!/usr/bin/lua5.1
-- requires dpkg and lua-filesystem
-- rewrite in python?

function add_uniq(set, e)
	if e and not(set[e]) then
    set[e]=true
		set[#set+1]=e
	end
end

require "lfs"

function not_dot(x) return x ~= "." and x ~= ".." end

templ=arg[1] or error "1st argument: the template index file"
_=arg[2] or error "following argument: the repo root path(s)"
table.remove(arg,1)

packages = {}

function do_one_root(suite)
  root = suite .. '/packages/'
  for p in lfs.dir(root) do if not_dot(p) then
		local pn, v = p:match('^([^%.]*)%.(.*)$')
		if v then p = pn end
  	packages[p] = packages[p] or {}
  	local info = packages[p]

		info.suites = info.suites or {}
		add_uniq(info.suites, suite)
  
  	local versions = info.versions or {}
		local curv
		if v then --simply a package
			curv = v
			add_uniq(versions, v)
		else -- a dir of packages
  	  for pv in lfs.dir(root .. p .. '/') do if not_dot(pv) then
  	  	local v = assert(pv:match('^[^%.]*%.(.*)$'),
  	  		root .. p .. '/' .. pv .. " not pkg.version")
  	  	add_uniq(versions, v)
			  curv = v
  	  end end
  	end
  	table.sort(versions,function(a,b)
      return 0 == os.execute('dpkg --compare-versions '..a..' gt '..b)
    end)
  	info.versions = versions
  
  	local pkg
		if v then pkg = root..p..'.'..curv
		else pkg = root..p..'/'..p..'.'..curv end
  
  	local opam = assert(io.open(pkg..'/opam')):read('*a')
  	local tags = opam:match('tags: *(%b[])') or ""
  
  	local keywords = info.keywords or {}
  	local dates = info.dates or {}
  	local categories = info.categories or {}
  	for tag in tags:gmatch('(%b"")') do
  		add_uniq(categories, tag:match('"category:([^"]*)"'))
  		add_uniq(keywords, tag:match('"keyword:([^"]*)"'))
  		add_uniq(dates, tag:match('"date:([^"]*)"'))
  	end
  	info.categories = categories
  	info.keywords = keywords
  	info.dates = dates
  	info.homepage = info.homepage or opam:match('homepage: *"([^"]*)"')
  
  	info.description = info.description or io.open(pkg..'/descr'):read('*a')
  
  end end
end

for _, r in ipairs(arg) do
	do_one_root(r)
end

function print_pkg(name,info,print)
	print [[ <tr class="package"><td> ]]
	if info.homepage ~= "" then print(('<a href="%s">'):format(info.homepage or "#")) end
	print (([[<h3 class="name">%s</h3>]]):format(name))
	if info.homepage ~= "" then print "</a>" end
	print (([[<p class="description">%s</p>]]):format(info.description))
	print [[<div class="metadata">]]
	if #info.keywords > 0 then
	  print [[<div class="keywords">keywords: ]]
	  	for _,k in ipairs(info.keywords) do
	  		print (([[<span class="keyword">%s</span>]]):format(k))
	  	end
	  print [[</div>]]
	end
	if #info.categories > 0 then
	  print [[<div class="categories">categories: ]]
	  	for _,k in ipairs(info.categories) do
	  		print (([[<span class="category">%s</span>]]):format(k))
	  	end
	  print [[</div>]]
	end
	if #info.dates > 0 then
	  print [[<div class="dates">date: ]]
	  	for _,k in ipairs(info.dates) do
	  		print (([[<span class="date">%s</span>]]):format(k))
	  	end
	  print [[</div>]]
	end
	print [[<div class="versions">versions: ]]
	for _,k in ipairs(info.versions) do
	 	print (([[<span class="version">%s</span>]]):format(k))
	end
	print [[</div>]]
	print [[<div class="suites">suites: ]]
	for _,k in ipairs(info.suites) do
	 	print (([[<span class="suite">%s</span>]]):format(k))
	end
	print [[</div>]]
	print [[</div>]]
	print [[</div>]]
	print [[ </td></tr> ]]
end

template = io.open(templ):read('*a')
output = io.open(templ:gsub('%.in$',''),'w')

output:write((template:gsub('@@PACKAGES@@', function()
	local t = {}
	local function print(s) t[#t+1] = s end
  for p, info in pairs(packages) do print_pkg(p,info,print) end
	return table.concat(t)
end)))

-- vim:set ts=2:
