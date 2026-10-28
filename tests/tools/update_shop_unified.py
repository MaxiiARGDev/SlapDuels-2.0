from pathlib import Path
p=Path("src/client/Controllers/ShopController.luau")
s=p.read_text(encoding="utf-8")
a=s.index('\t\t\tif product.Category == "Crates" then\n\t\t\t\tlocal actionsTemplate')
b=s.index('\n\t\tlocal previewStroke',a)
s=s[:a]+s[b:]
s=s.replace('if icon and type(product.Icon)', 'if product.Category ~= "Crates" and icon and type(product.Icon)')
s=s.replace('if badge then badge.Visible=true;badge.Text=if state.Quantity>0 then state.Quantity.." cajas" else state.Badge end','if badge then badge.Visible=false end')
s=s.replace('card.Visible = true','card.Visible = true\n\t\tShopLayout.Card(card)',1)
s=s.replace('if product.Category == "Crates" then rarityLabel.Text="Favorece: "..(product.Metadata and product.Metadata.FavouredVariations or "Pendiente") end','if product.Category == "Crates" then rarityLabel.Visible=false end')
s=s.replace('self._selectedId = productId\n\t\t\tself:_refreshStates()', 'self._selectedId = productId\n\t\t\tself._detailFocused=true\n\t\t\tself:_refreshStates()')
s=s.replace('ui.Catalog.Visible = not loading and not isEmpty','ui.Catalog:SetAttribute("HasProducts",not loading and not isEmpty)\n\tui.Catalog.Visible = not loading and not isEmpty')
a=s.index('\tif product.Category == "Crates" then',s.index('function ShopController:_renderDetail()'))
b=s.index('\n\tlocal oldCrate',a)
s=s[:a]+''' local crate=self._context:GetController("CrateController")
 if product.Category == "Crates" then
  d.Frame.Visible=false
  if crate then crate:ShowCrate(product.Id,true)end
  ShopLayout.Apply(ui.Hud,self._detailFocused)
  return
 end
 if crate and crate._panel then crate._panel.Visible=false end
 d.Frame.Visible=true
 ShopLayout.Apply(ui.Hud,self._detailFocused)
'''+s[b:]
s=s.replace('self._category = category\n\tself._selectedId = nil','self._category = category\n\tself._detailFocused=false\n\tself._selectedId = nil')
s=s.replace('self:_renderDetail()\n\tself:_renderCoins()', 'self:_renderDetail()\n\tself:_renderCoins()\n\tif self._ui then ShopLayout.Apply(self._ui.Hud,self._detailFocused)end')
# Fallback initialized before either real preview; never re-enabled afterwards.
s=s.replace('local icon2dFolder =', '''local fallback=preview:FindFirstChild("PreviewIcon")
 if fallback then fallback.Visible=true end
 local icon2dFolder =''',1)
p.write_text(s,encoding="utf-8")
