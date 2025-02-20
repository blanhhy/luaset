local _M = {}


-- type元方法
local function type_meta(self)
  return getmetatable(self).__classname
end


-- 具体集合
-- 所有具体集合共享一个元表
local public_meta = {
  __classname = "concrete set",
  __type = type_meta,
  __tostring = function(self)
    return "{ " .. table.concat(_M.toStrArray(self), ", ") .. " }"
  end,
  -- 向集合中加入元素
  __call = function(self, elmt)
    return rawget(self, elmt) or rawset(self, elmt, true)
  end,
  -- 小于等于号（包含于⊆）
  __le = function(self, another)
    local _tp = type(another)
    if _tp ~= "concrete set" and _tp ~= "abstract set" then
      error("attempt to compare a ".. _tp .." with a set. ", 2)
    end
    if rawequal(self, another) then
      return true
    end
    local state = true
    for elmt in next, self do
      if not another[elmt] then
        state = false
        break
      end
    end
    return state
  end,
  -- 小于号（真包含于⫋）
  __lt = function(self, another)
    if (not rawequal(self, another)) and type(another) == "concrete set" and #self < #another then
      local state = true
      for elmt in next, self do
        if not another[elmt] then
          state = false
          break
        end
      end
      return state
    end
    error("attempt to compare a ".. type(another) .." with a concrete set. ", 2)
  end,
  -- 等于号
  __eq = function(self, another)
    if rawequal(self, another) then
      return true
    end
    if type(another) == "concrete set" and #self == #another then
      local state = true
      for elmt in next, self do
        if not another[elmt] then
          state = false
          break
        end
      end
      return state
    end
    return false
  end,
  -- 加号（并集∪）
  __add = function(self, another)
    local _tp = type(another)
    if _tp == "concrete set" then
      local union = {}
      for elmt in next, self do
        rawset(union, elmt, true)
      end
      for elmt in next, another do
        if not union[elmt] then
          rawset(union, elmt, true)
        end
      end
      return setmetatable(union, public_meta)
--[[     elseif _tp == "abstract set" then
      local union, meta = _M.clone(another)
      return union]]
    end
  end,
  -- 乘号（交集）
  __mul = function(self, another)
    local _tp = type(another)
    if _tp == "concrete set" then
      local intersection = {}
      for elmt in next, self do
        rawset(intersection, elmt, another[elmt])
      end
      return intersection
--[[     elseif _tp == "abstract set" then
      local intersection, meta = _M.clone(another)
      
      return setmetatable(intersection, meta)]]
    end
  end,
  -- 减号（差集）
  __sub = function(self, another)
    local _tp = type(another)
    if _tp == "concrete set" then
      local sub = {}
      for elmt in next, self do
        if not another[elmt] then
          rawset(sub, elmt, true)
        end
      end
      return sub
--     elseif _tp == "abstract set" then
      
    end
  end,
  -- 负号（补集）
  __unm = function(self)
    local meta = getmetatable(self)
    local U = meta.U
    local complement_set = meta.complement_set
    if not complement_set then
      meta.complement_set = setmetatable(U and U - self or _M.assert(function(elmt) return not self[elmt] end))
    end
  end,
}


-- 枚举法
-- 1. 用一系列参数构造集合
function _M.of(...)
  local ary = table.pack(...)
  local aset = {}
  for i = 1, ary.n do
    rawset(aset, ary[i], true)
  end
  return setmetatable(aset, public_meta)
end


-- 2. 通过一个数组生成集合
function _M.ofArray(ary)
  local aset = {}
  for i = 1, #ary do
    rawset(aset, ary[i], true)
  end
  return setmetatable(aset, public_meta)
end


-- 3. 通过table的索引生成集合
function _M.ofIndex(tb)
  local aset = {}
  for index in next, tb do
    rawset(aset, index, true)
  end
  return setmetatable(aset, public_meta)
end


-- 4. 通过table中的值生成集合
function _M.ofValue(tb)
  local aset = {}
  for index, value in next, tb do
    rawset(aset, value, true)
  end
  return setmetatable(aset, public_meta)
end


-- 把一个具体集合（或抽象集合缓存）变为数组
function _M.toArray(aset)
  local _tp = type(aset)
  if _tp ~= "concrete set" and _tp ~= "abstract set" then
    return nil
  end
  local ary = {}
  for elmt in next, aset do
    table.insert(ary, elmt)
  end
  return ary
end


-- 把一个具体集合（或抽象集合缓存）变为字符串数组
function _M.toStrArray(aset)
  local _tp = type(aset)
  if _tp ~= "concrete set" and _tp ~= "abstract set" then
    return nil
  end
  local ary = {}
  for elmt in next, aset do
    table.insert(ary, tostring(elmt))
  end
  return ary
end


-- 设置全集
function _M.setU(aset, U)
  if not U then
    public_meta.U = aset
  end
  getmetatable(aset).U = U
end


-- 获取全集
function _M.getU(aset)
  if not aset then
    return public_meta.U
  end
  return getmetatable(aset).U
end


-- 抽象集合
-- 所有抽象集合共享一个__index元方法
local public_index = function(self, elmt)
  local assertion = getmetatable(self)[1]
  -- 遍历所有断言判断元素是否在集合内
  for i = 1, assertion.n do
    local sucsess, bool = pcall(assertion[i], elmt)
    if not (sucsess and bool) then
      return false
    end
  end
  -- 判断元素类型，并根据类型决定是否缓存
  if StaticValueTypes(type(elmt)) then
    -- 缓存已经确认在集合内的静态元素
    rawset(self, elmt, true)
  end
  return true
end


-- 描述法
-- 用一系列断言来构造集合，通过所有断言来判断元素是否在集合内
function _M.assert(...)
  local meta = {
    table.pack(...),
    __classname = "abstract set",
    __type = type_meta,
    __index = public_index,
    __call = public_index,
    __tostring = public_meta.__tostring,
  }
  local aset = setmetatable({}, meta)
  return aset
end


-- 获取抽象集合的缓存，返回一个具体集合
function _M.getCache(aset)
  if type(aset) ~= "abstract set" then
    return nil
  end
  return setmetatable(table.clone(aset), public_meta)
end


-- 清空并返回抽象集合的缓存
function _M.clear(aset)
  if type(aset) ~= "abstract set" then
    return nil
  end
  local bset = {}
  for elmt in next, aset do
    rawset(bset, elmt, true)
    rawget(aset, elmt, nil)
  end
  return setmetatable(bset, public_meta)
end


-- 复制抽象集合
function _M.clone(aset)
  local base = getmetatable(aset)
  local trust = base[2]
  local concrete = base.concrete_set
  local replica = {
    table.clone(base[1]),
    trust and table.clone(trust),
    __type = type_meta,
    __index = public_index,
    __call = public_index,
    __classname = base.__classname,
    __tostring = base.__tostring,
    __add = base.__add,
    __mul = base.__mul,
    __sub = base.__sub,
    __unm = base.__unm,
    concrete_set = concrete and table.clone(concrete)
  }
  return setmetatable({}, replica), replica
end


-- 直接调用这个模块会尝试用两种方法生成具体集合
setmetatable(_M, {
  __call = function(_m, ...)
    if select('#', ...) == 1 and type(...) == "table" then
      return _m.ofArray(...)
     else
      return _m.of(...)
    end
  end
})


StaticValueTypes = _M.of("number", "boolean", "string")


return _M