# Joins User_F.lua into a single line for the Roblox console command bar.
import pathlib
here = pathlib.Path(__file__).parent
lines = [l.strip() for l in (here / "User_F.lua").read_text().splitlines()]
code = " ".join(l for l in lines if l and not l.startswith("--"))
(here / "User_F.oneline.lua").write_text(code + "\n")
print(len(code), "chars")
