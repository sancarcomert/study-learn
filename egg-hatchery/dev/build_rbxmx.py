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
    item("Script", n, read(f"ServerScriptService/{n}.server.lua")) for n in ("EconomyManager", "BoothManager", "MarketplaceHook")
])
write("StarterGui.rbxmx", [item("LocalScript", "EggClient", read("StarterGui/EggClient.client.lua"))])
write("StarterPlayerScripts.rbxmx", [item("LocalScript", "MapFX", read("StarterPlayer/StarterPlayerScripts/MapFX.client.lua"))])
