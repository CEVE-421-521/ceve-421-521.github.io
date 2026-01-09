-- Material link shortcode with status-aware styling
-- Usage: {{< material type="lectures" id="week-01" label="Lecture:"
--          text="Title" href="path.qmd" slides="path.html" >}}

local status_registry = nil

-- Load status from _status.yml
local function load_status_registry()
  if status_registry ~= nil then
    return status_registry
  end

  local f = io.open("_status.yml", "r")
  if not f then
    quarto.log.warning("[status] Could not open _status.yml - defaulting to published")
    status_registry = {}
    return status_registry
  end

  local content = f:read("*all")
  f:close()

  -- Parse YAML (simple format: section:\n  key: value)
  status_registry = {}
  local current_section = nil

  for line in content:gmatch("[^\r\n]+") do
    -- Check for section header (no leading whitespace, ends with colon)
    local section = line:match("^(%w+):%s*$")
    if section then
      current_section = section
      status_registry[current_section] = {}
    elseif current_section then
      -- Check for key-value pair (leading whitespace)
      -- Handle both quoted ("value") and unquoted (value) formats
      local key, value = line:match('^%s+([%w%-]+):%s*"?(%w+)"?')
      if key and value then
        status_registry[current_section][key] = value
      end
    end
  end

  return status_registry
end

-- Get status for a material (defaults to "published" if not found)
local function get_status(material_type, material_id)
  local reg = load_status_registry()
  if reg[material_type] and reg[material_type][material_id] then
    return reg[material_type][material_id]
  end
  return "published"
end

-- Check if string is empty or nil
local function is_empty(s)
  return s == nil or s == ""
end

-- Main shortcode function
return {
  -- Draft warning callout for document pages
  ["draft-warning"] = function(args, kwargs, meta)
    -- Check the document's own status metadata
    local status = pandoc.utils.stringify(meta["status"] or "published")
    if status ~= "draft" then
      return pandoc.Null()
    end

    if quarto.doc.is_format("html:js") then
      return pandoc.RawBlock("html", [[
<div class="callout callout-warning callout-style-default callout-captioned">
<div class="callout-header d-flex align-content-center">
<div class="callout-icon-container"><i class="callout-icon"></i></div>
<div class="callout-caption-container flex-fill">Draft Material</div>
</div>
<div class="callout-body-container callout-body">
<p>This content is under development and subject to change.</p>
</div>
</div>
]])
    elseif quarto.doc.is_format("typst") then
      return pandoc.RawBlock("typst", [[
#block(
  fill: rgb("#fff3cd"),
  inset: 10pt,
  radius: 4pt,
  [*Draft Material* — This content is under development and subject to change.]
)
]])
    else
      return pandoc.Para({pandoc.Strong({pandoc.Str("Draft Material:")}), pandoc.Space(), pandoc.Str("This content is under development and subject to change.")})
    end
  end,

  ["material"] = function(args, kwargs)
    -- Extract parameters
    local mtype = pandoc.utils.stringify(kwargs["type"] or "")
    local mid = pandoc.utils.stringify(kwargs["id"] or "")
    local label = pandoc.utils.stringify(kwargs["label"] or "")
    local text = pandoc.utils.stringify(kwargs["text"] or "")
    local href = pandoc.utils.stringify(kwargs["href"] or "")
    local slides = pandoc.utils.stringify(kwargs["slides"] or "")
    local slidepdf = pandoc.utils.stringify(kwargs["slidepdf"] or "")

    -- Determine status
    local status = get_status(mtype, mid)
    local is_draft = (status == "draft")

    -- Build the content
    if quarto.doc.is_format("html:js") then
      local html = ""

      -- Open draft wrapper if needed
      if is_draft then
        html = html .. '<span class="draft-material">'
      end

      -- Label (bold)
      if not is_empty(label) then
        html = html .. "<strong>" .. label .. "</strong> "
      end

      -- Main link
      html = html .. '<a href="' .. href .. '">' .. text .. '</a>'

      -- Slide links (if provided)
      if not is_empty(slides) or not is_empty(slidepdf) then
        html = html .. " ["
        if not is_empty(slides) then
          html = html .. '<a href="' .. slides .. '"><i class="fa-solid fa-display"></i></a>'
        end
        if not is_empty(slides) and not is_empty(slidepdf) then
          html = html .. " "
        end
        if not is_empty(slidepdf) then
          html = html .. '<a href="' .. slidepdf .. '"><i class="fa-solid fa-file-pdf"></i></a>'
        end
        html = html .. "]"
      end

      -- Close draft wrapper and add badge
      if is_draft then
        html = html .. ' <span class="draft-badge">in prep</span></span>'
      end

      return pandoc.RawInline("html", html)

    elseif quarto.doc.is_format("typst") then
      local typst = ""

      -- Open draft styling if needed
      if is_draft then
        typst = typst .. "#text(fill: luma(120))["
      end

      -- Label (bold)
      if not is_empty(label) then
        typst = typst .. "*" .. label .. "* "
      end

      -- Main link
      typst = typst .. '#link("' .. href .. '")[' .. text .. ']'

      -- Note: slide icons simplified for Typst
      if not is_empty(slides) then
        typst = typst .. ' #link("' .. slides .. '")[slides]'
      end

      -- Close draft styling and add badge
      if is_draft then
        typst = typst .. " _(in prep)_]"
      end

      return pandoc.RawInline("typst", typst)

    else
      -- Fallback: plain text
      local result = ""
      if not is_empty(label) then
        result = result .. label .. " "
      end
      result = result .. text
      if is_draft then
        result = result .. " (in prep)"
      end
      return pandoc.Str(result)
    end
  end
}
