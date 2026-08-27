# PiPing visual identity

The files in `Source` are the designer-authored Figma exports. They are retained
as editable reference material and are not bundled into either app target.

`Runtime/MenuBar` contains the monochrome default template plus the two
designer-authored attention appearances used by the macOS menu-bar label.
macOS supplies the foreground color for the default symbol. The attention
symbol is rendered as one original-color image so the red unread dot is not
flattened away by the system status-item template treatment.

`AppIcon/PiPing.icon` is the Icon Composer source used by both the macOS and iOS
targets. It remains the canonical app icon; flattened PNG exports are not tracked
or shipped.
