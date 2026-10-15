# Builds from User_F.lua:
#   User_F.oneline.lua      - single line for the Roblox console command bar (all effects on)
#   User_F_Core.server.lua  - Creator Store friendly Script for a model with a "Core" part
#                             (from User_F_Core.template.lua: effects outside the model off,
#                             no dismemberment, formatted with StyLua if it is on PATH or STYLUA is set)
import os, pathlib, re, shutil, subprocess
here = pathlib.Path(__file__).parent
src = (here / "User_F.lua").read_text()

lines = [l.strip() for l in src.splitlines()]
code = " ".join(l for l in lines if l and not l.startswith("--"))
(here / "User_F.oneline.lua").write_text(code + "\n")
print(len(code), "chars")

# store version: header + settings block come from the template (settings at the top of the Script)
store_lines = src.splitlines()[4:]
start = next(i for i, l in enumerate(store_lines) if l.startswith("-- settings"))
end = next(i for i, l in enumerate(store_lines) if l.startswith("-- BREAK_ANYTHING")) + 1
store = "\n".join(store_lines[:start] + store_lines[end:]) + "\n"
# store version: it shakes the player instead of tearing limbs off
store = re.sub(r"--@@GORE_BEGIN\n.*?--@@GORE_END\n",
               'for i=1,4 do task.wait(0.55) snd("rbxasset://sounds/collide.wav",tr,4,math.random(3,6)/10) say(MSG,2) end\n',
               store, flags=re.S)
tpl = (here / "User_F_Core.template.lua").read_text()
out = here / "User_F_Core.server.lua"
out.write_text(tpl.replace("--@@USER_F_BODY@@", store))
stylua = os.environ.get("STYLUA") or shutil.which("stylua")
if stylua:
    subprocess.run([stylua, "--syntax", "Luau", str(out)], check=True)
else:
    print("stylua not found: User_F_Core.server.lua left unformatted")
