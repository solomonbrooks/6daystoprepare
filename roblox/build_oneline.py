# Builds from User_F.lua:
#   User_F.oneline.lua      - single line for the Roblox console command bar
#   User_F_Core.server.lua  - Script for a model with a "Core" part (from User_F_Core.template.lua)
import pathlib
here = pathlib.Path(__file__).parent
src = (here / "User_F.lua").read_text()
lines = [l.strip() for l in src.splitlines()]
code = " ".join(l for l in lines if l and not l.startswith("--"))
(here / "User_F.oneline.lua").write_text(code + "\n")
print(len(code), "chars")
body = "\n".join(l for l in src.splitlines() if not l.startswith("--"))
tpl = (here / "User_F_Core.template.lua").read_text()
(here / "User_F_Core.server.lua").write_text(tpl.replace("--@@USER_F_BODY@@", body))
