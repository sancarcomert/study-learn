#!/usr/bin/env python3
"""dev/build_rbxmx.py -- depodaki scriptlerden Studio'ya 'Insert from File' ile eklenecek .rbxmx dosyalari uretir.
Cikti: studio_files/ServerScriptService.rbxmx, StarterGui.rbxmx, StarterPlayerScripts.rbxmx
Kopyala-yapistir yok: dosyalar Explorer'da hedef servise sag tik > Insert from File ile eklenir."""
import itertools
import pathlib
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "studio_files"
OUT.mkdir(exist_ok=True)
ids = itertools.count()


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, source=None, children=()):
    ref = f"RBX{next(ids)}"
    props = f'<string name="Name">{name}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    return f'<Item class="{cls}" referent="{ref}"><Properties>{props}</Properties>{"".join(children)}</Item>'


def read(rel):
    t = (ROOT / rel).read_text(encoding="utf-8")
    assert t.endswith("\n")
    return t


def write(fname, items):
    xml = '<?xml version="1.0" encoding="utf-8"?>\n<roblox version="4">' + "".join(items) + "</roblox>\n"
    ET.fromstring(xml.encode("utf-8"))  # iyi bicimli mi
    (OUT / fname).write_text(xml, encoding="utf-8")
    print(f"yazildi: {OUT / fname} ({len(xml)} bayt)")


mods = [item("ModuleScript", n, read(f"ServerScriptService/Modules/{n}.lua")) for n in ("Config", "Remotes", "BoothRegistry", "HatcheryService")]
write("ServerScriptService.rbxmx", [item("Folder", "Modules", None, mods)] + [
    item("Script", n, read(f"ServerScriptService/{n}.server.lua")) for n in ("EconomyManager", "BoothAdapter", "BoothManager", "MarketplaceHook", "LeaderboardService")
])
write("StarterGui.rbxmx", [item("LocalScript", "EggClient", read("StarterGui/EggClient.client.lua"))])
write("StarterPlayerScripts.rbxmx", [item("LocalScript", "MapFX", read("StarterPlayer/StarterPlayerScripts/MapFX.client.lua"))])


# --- BoothRing.rbxmx: Workspace'e eklenir. Sari disk (BoothRing) + icinde Script. Disk surukle/boyutlandir -> Play'de standlar halka olur.
def part_disc(source):
    ref = f"RBX{next(ids)}"
    color = (255 << 24) | (255 << 16) | (200 << 8) | 60  # sari
    props = (
        '<string name="Name">BoothRing</string>'
        '<bool name="Anchored">true</bool>'
        '<bool name="CanCollide">false</bool>'
        '<bool name="Locked">false</bool>'
        '<float name="Transparency">0.35</float>'
        f'<Color3uint8 name="Color3uint8">{color}</Color3uint8>'
        '<token name="shape">2</token>'
        '<Vector3 name="size"><X>0.5</X><Y>168</Y><Z>168</Z></Vector3>'
        '<CoordinateFrame name="CFrame"><X>0</X><Y>1</Y><Z>0</Z>'
        '<R00>0</R00><R01>-1</R01><R02>0</R02><R10>1</R10><R11>0</R11><R12>0</R12><R20>0</R20><R21>0</R21><R22>1</R22></CoordinateFrame>'
    )
    return f'<Item class="Part" referent="{ref}"><Properties>{props}</Properties>{item("Script", "BoothRingBuilder", source)}</Item>'


write("BoothRing.rbxmx", [part_disc(read("studio_src/BoothRing.server.lua"))])
