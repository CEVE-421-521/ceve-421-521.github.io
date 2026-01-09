-- Pandoc filter to automatically inject draft warning callout
-- This runs on every document and checks for status: draft in metadata

local function create_draft_callout()
  -- Check format using Quarto's API if available, otherwise use FORMAT global
  local is_html = false
  local is_typst = false
  local is_revealjs = false
  local is_beamer = false

  if quarto and quarto.doc and quarto.doc.is_format then
    is_html = quarto.doc.is_format("html:js")
    is_typst = quarto.doc.is_format("typst")
    is_revealjs = quarto.doc.is_format("revealjs")
    is_beamer = quarto.doc.is_format("beamer")
  elseif FORMAT then
    is_html = FORMAT:match("html") ~= nil
    is_typst = FORMAT:match("typst") ~= nil
    is_revealjs = FORMAT:match("revealjs") ~= nil
    is_beamer = FORMAT:match("beamer") ~= nil
  end

  if is_revealjs then
    -- For slides, add a banner at the top
    return pandoc.RawBlock("html", [[
<div class="callout callout-warning" style="margin-bottom: 1em;">
<div class="callout-body"><strong>Draft:</strong> This content is under development.</div>
</div>
]])
  elseif is_html then
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
  elseif is_typst then
    return pandoc.RawBlock("typst", [[
#block(
  fill: rgb("#fff3cd"),
  inset: 10pt,
  radius: 4pt,
  [*Draft Material* — This content is under development and subject to change.]
)
]])
  elseif is_beamer then
    return pandoc.RawBlock("latex", [[
\begin{block}{Draft Material}
This content is under development and subject to change.
\end{block}
]])
  else
    return pandoc.Para({
      pandoc.Strong({pandoc.Str("Draft Material:")}),
      pandoc.Space(),
      pandoc.Str("This content is under development and subject to change.")
    })
  end
end

return {
  {
    Pandoc = function(doc)
      -- Check the document's status metadata
      local status = doc.meta["status"]
      if status == nil then
        return doc
      end

      local status_str = pandoc.utils.stringify(status)
      if status_str ~= "draft" then
        return doc
      end

      -- Insert the callout at the beginning of the document
      local callout = create_draft_callout()
      table.insert(doc.blocks, 1, callout)

      return doc
    end
  }
}
