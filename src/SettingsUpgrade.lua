-- Add missing schema defaults before the menu reads the on-disk INI.
-- Existing choices are retained; retired slider values snap to the closest picker step.
-- Transactions run only at settings-load boundaries.
local Store=require('SettingsStore')
local M={}
function M.complete(original,schema)
    local text=original:gsub('^\239\187\191','')
    -- The menu does not accept a BOM before a section or inline section comments.
    -- Normalize Settings headers only; retain any header comment on its own line.
    local lines={}
    for full in (text..'\n'):gmatch('([^\n]*\n)') do
        local body,eol=full:match('^(.-)(\r?\n)$')
        local tail=body:match('^%s*%[%s*Settings%s*%](.*)$')
        if tail and (tail:match('^%s*$') or tail:match('^%s*[;#]')) then
            local comment=tail:match('^%s*([;#].*)$')
            full='[Settings]'..eol..(comment and comment..eol or '')
        end
        lines[#lines+1]=full
    end
    text=table.concat(lines):sub(1,-2) -- Remove only the synthetic final newline.
    local present,legacy,section={},{},''
    for line in (text..'\n'):gmatch('(.-)\r?\n') do
        line=line:gsub('[;#].*$',''):match('^%s*(.-)%s*$')
        local header=line:match('^%[([^%]]+)%]$')
        if header then section=header
        elseif section=='Settings' then
            local key,value=line:match('^([%w_]+)%s*=%s*(.-)%s*$')
            if key then
                present[key]=(present[key] or 0)+1
                legacy[key]=tonumber(value)
            end
        end
    end
    -- The 1.0 Black & White picker uses 5% steps. Retain an old between-step
    -- assignment as a comment and back up the untouched file through load().
    if present.monochrome==1 and legacy.monochrome and legacy.monochrome>=0
        and legacy.monochrome<=100 and legacy.monochrome%1==0 and legacy.monochrome%5~=0 then
        local value=5*math.floor(legacy.monochrome/5+0.5)
        local sectionName=''
        local normalized={}
        for full in (text..'\n'):gmatch('([^\n]*\n)') do
            local body,eol=full:match('^(.-)(\r?\n)$')
            local clean=body:gsub('[;#].*$',''):match('^%s*(.-)%s*$')
            local header=clean:match('^%[([^%]]+)%]$')
            if header then sectionName=header
            elseif sectionName=='Settings' and clean:match('^monochrome%s*=') then
                full='; Before 1.0 percentage picker: '..body..eol..'monochrome = '..value..eol
            end
            normalized[#normalized+1]=full
        end
        text=table.concat(normalized):sub(1,-2)
    end
    local added={}
    local migratedBrightness
    if not present.brightnessPercent and present.brightness then
        if present.brightness~=1 or not legacy.brightness or legacy.brightness~=legacy.brightness
            or legacy.brightness < -2 or legacy.brightness > 4 then
            return nil,'Invalid or duplicate legacy brightness'
        end
        -- Retain the old assignment as a record. The new key takes precedence.
        -- Radius preserves its former light strength; fullscreen converts EV to %.
        local offset=legacy.nightVisionMode==0 and 0.5 or 0
        migratedBrightness=math.max(25,math.min(300,5*math.floor(20*2^(legacy.brightness+offset)+0.5)))
    end
    for _,field in ipairs(schema) do
        if not present[field.key] then
            local value=field.key=='brightnessPercent' and migratedBrightness or field.default
            added[#added+1]=field.key..' = '..string.format('%.17g',value)
        end
    end
    if #added>0 then
        local newline=text:find('\r\n',1,true) and '\r\n' or '\n'
        if text~='' and text:sub(-1)~='\n' then text=text..newline end
        text=text..'[Settings]'..newline..table.concat(added,newline)..newline
    end
    -- Validate all existing/new values and reject duplicates before any file write.
    local values,err=Store.parse(text,schema)
    return values,err,text
end
local function readOptional(path)
    local text,err,code=Store.read(path)
    assert(text~=nil or code==2,err or ('Cannot read '..path))
    return text
end
local function remove(path) local ok,err=os.remove(path);assert(ok,err) end
local function rename(a,b) local ok,err=os.rename(a,b);assert(ok,err) end
local function load(directory,schema,defaults)
    local path=Store.path(directory)
    local tmp,previous=path..'.nv-upgrade.tmp',path..'.nv-upgrade.previous'
    local original,staged,old=readOptional(path),readOptional(tmp),readOptional(previous)
    if old then
        local values,err,expected=M.complete(old,schema);assert(values,err)
        -- Recover an interrupted rename, without overwriting an external edit.
        assert(original==nil or original==old or original==expected,'Settings changed during interrupted upgrade; originals retained at '..previous)
        assert(staged==nil or staged==expected,'Unexpected upgrade temporary file; retained at '..tmp)
        if original==nil then rename(previous,path);original=old
        else remove(previous) end
        if staged then remove(tmp);staged=nil end
    elseif staged then
        local values,err,expected=M.complete(assert(original,'Settings missing during upgrade'),schema)
        assert(values,err);assert(staged==expected,'Unexpected upgrade temporary file; retained at '..tmp)
        remove(tmp)
    end
    if not original then return Store.load(directory,schema,function()return defaults end) end
    local values,err,updated=M.complete(original,schema)
    if not values then return nil,err end
    if updated==original then return values end
    -- Keep the first pre-upgrade snapshot, including comments and unrelated sections.
    local backup=path..'.before-upgrade'
    if not readOptional(backup) then
        local ok,why=Store.create(backup,original);assert(ok,why)
        assert(Store.read(backup)==original,'Settings backup verification failed')
    end
    assert(Store.read(path)==original,'Settings changed before upgrade; retry after reopening')
    local ok,why=Store.create(tmp,updated);assert(ok,why)
    if Store.read(tmp)~=updated or Store.read(path)~=original then
        remove(tmp);error('Settings changed or upgrade temporary verification failed')
    end
    local moved,moveError=os.rename(path,previous)
    if not moved then remove(tmp);error(moveError) end
    local installed,installError=pcall(function()
        assert(Store.read(previous)==original,'Settings changed during upgrade')
        rename(tmp,path)
    end)
    if not installed then
        local restored,restoreError=os.rename(previous,path)
        if restored and readOptional(tmp) then remove(tmp) end
        error(tostring(installError)..(restored and '; original restored' or '; original retained at '..previous..': '..tostring(restoreError)))
    end
    assert(Store.read(path)==updated,'Settings upgrade verification failed; original retained at '..previous)
    remove(previous)
    return values
end
function M.load(directory,schema,defaults)
    local ok,values,err=pcall(load,directory,schema,defaults)
    if ok then return values,err end
    return nil,tostring(values)
end
return M
