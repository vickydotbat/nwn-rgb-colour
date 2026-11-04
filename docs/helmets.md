# Why worn helmets keep their stock colours

A worn helmet drops every value a script sets. The engine sends an item's shader values to clients only while the item lies in an area. Once a character wears the helmet, the client rebuilds it from the item without those values. NWScript has no call that sends them again, so this package leaves helmets out.

A server with a plugin layer, such as NWNX or Anvil, could likely fix it. The plugin would resend the helmet's values to each client as a game object update: on equip, on area entry, on relog, and on every change. Nobody has tested this in game yet. Treat it as a lead, not a recipe.
