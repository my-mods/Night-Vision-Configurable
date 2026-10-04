-- A small colour lookup texture preserves red shades after tone mapping.
-- No world-object searches or changes to blood materials are needed.
local M={}
local function valid(o) return o~=nil and o:IsValid() end
local function object(path)
    local value=StaticFindObject(path);assert(valid(value),'Unavailable '..path);return value
end
local function signature(path,expected)
    local fn=object(path);local index=0
    fn:ForEachProperty(function(p)
        index=index+1;local spec=expected[index]
        assert(spec and p:GetFName():ToString()==spec[1]
            and p:GetFullName():match('^(%S+)')==spec[2],'Unsupported signature: '..path)
    end)
    assert(index==#expected,'Incomplete signature: '..path)
end
function M.new(directory)
    local texture
    return function(context)
        -- Legacy colour lookup tables are a display-referred SDR operation.
        -- Do not bypass ordinary desaturation on an HDR output path.
        signature('/Script/Engine.KismetSystemLibrary:GetConsoleVariableIntValue',{
            {'VariableName','StrProperty'},{'ReturnValue','IntProperty'}})
        local system=object('/Script/Engine.Default__KismetSystemLibrary')
        assert(system:GetConsoleVariableIntValue('r.HDR.EnableHDROutput')==0,'Keep blood red requires HDR output to be off')
        if valid(texture) then return texture end
        signature('/Script/Engine.KismetRenderingLibrary:ImportFileAsTexture2D',{
            {'WorldContextObject','ObjectProperty'},{'Filename','StrProperty'},{'ReturnValue','ObjectProperty'}})
        signature('/Script/Engine.Texture2D:Blueprint_GetSizeX',{{'ReturnValue','IntProperty'}})
        signature('/Script/Engine.Texture2D:Blueprint_GetSizeY',{{'ReturnValue','IntProperty'}})
        local library=object('/Script/Engine.Default__KismetRenderingLibrary')
        local class=object('/Script/Engine.Texture2D')
        local function load(name)
            local value=library:ImportFileAsTexture2D(context,directory..'../Textures/'..name)
            assert(valid(value) and value:IsA(class),'Blood colour texture could not be imported')
            assert(value:Blueprint_GetSizeX()==256 and value:Blueprint_GetSizeY()==16,'Invalid blood colour texture dimensions')
            assert(type(value.SRGB)=='boolean','Unknown blood colour texture encoding')
            return value
        end
        local value=load('KeepBloodRed.png')
        -- Account for the importer's actual GPU sampling mode without changing
        -- texture resource flags after creation. Both files encode the same LUT.
        if value.SRGB then
            value=load('KeepBloodRed-sRGB.png')
            assert(value.SRGB,'Blood colour texture encoding changed during import')
        end
        texture=value
        return texture
    end
end
return M
