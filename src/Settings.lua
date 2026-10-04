local M = {}
local Store = require('SettingsStore')
M.schema = {
    {key='enabled',values={0,1},default=1},
    {key='nightVisionMode',values={0,1},default=1},
    {key='vignette',values={0,1},default=1},
    {key='vignetteOpacity',min=0,max=100,integer=true,default=20},
    {key='monochrome',min=0,max=100,integer=true,default=0},
    {key='redMonochrome',min=0,max=100,integer=true,default=0},
    {key='brightness',min=-2,max=4,default=-0.5},
    {key='controllerInput',values={0,1},default=1},
    {key='debugLogging',values={0,1},default=0},
}
function M.start(directory, apply, report)
    local ids, defaults = {}, {}
    for _, field in ipairs(M.schema) do
        ids[field.key], defaults[field.key] = field.key, field.default
    end
    local live = require('UE4SSDawnwalkerSettings').new({
        modId='NightVisionConfigurable', schema=M.schema, ids=ids, report=report,
    })
    live.attach(apply)
    local function reload()
        -- Older files remain untouched. Fill only newly introduced keys in memory;
        -- the menu persists them on Apply. Existing fullscreen/colour choices survive.
        local text, readError, code=Store.read(Store.path(directory))
        local values, err
        if text then
            local legacy={nightVisionMode=1,vignette=1,vignetteOpacity=20,redMonochrome=0}
            local present,section={},''
            for line in (text:gsub('^\239\187\191','')..'\n'):gmatch('(.-)\r?\n') do
                line=line:gsub('[;#].*$',''):match('^%s*(.-)%s*$')
                local header=line:match('^%[([^%]]+)%]$')
                if header then section=header
                elseif section=='Settings' then
                    local key=line:match('^([%w_]+)%s*=');if key then present[key]=true end
                end
            end
            -- A separate Settings section permits filling keys without changing comments.
            local extra={'','[Settings]'}
            for key,value in pairs(legacy) do if not present[key] then extra[#extra+1]=key..'='..value end end
            values,err=Store.parse(text..table.concat(extra,'\n')..'\n',M.schema)
        elseif code==2 then
            values,err=Store.load(directory,M.schema,function() return defaults end)
        else err=readError end
        if values then live.seed(values); apply(values)
        else report('Settings: '..tostring(err)..'; previous values retained.') end
    end
    reload()
    live.start(function(id, callback) return require('dmm_api').subscribe(id, callback) end)
    return reload
end
return M
