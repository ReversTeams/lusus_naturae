SCP-914 1:1 custom skins

Add Minecraft player skin PNG files to this directory.
Supported layouts are 64x64 and legacy 64x32.

When a player passes through SCP-914 on the 1:1 setting, one PNG
from this directory is selected at random and stored on the player.

Bundled defaults: skin1.png, skin2.png, skin3.png, skin4.png, and
skin5.png. Additional PNG files are treated as custom skins.

Kleiders Custom Renderer is optional, but it must be installed on a
client for the selected SCP-914 skin to be rendered.

In multiplayer, each client must have the same skin filenames in
this directory. The server synchronizes the selected filename, not
the image bytes.
