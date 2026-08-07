import os
import subprocess


assert os.environ["POC_DEV_SHELL"] == "wsl-direnv"
assert os.getcwd().startswith("/mnt/")

print(f"python-child: {os.environ['POC_DEV_SHELL']}")
subprocess.run(
    ["bash", "-c", 'echo "bash-grandchild: $POC_DEV_SHELL"'],
    check=True,
)
