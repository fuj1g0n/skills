import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";

test("the complete child process tree inherits the WSL devShell", () => {
  assert.equal(process.env.POC_DEV_SHELL, "wsl-direnv");
  assert.match(process.cwd(), /^\/mnt\/[a-z]\//);

  const child = spawnSync(
    "uv",
    ["run", "--no-project", "--python", "python3", "test/python-child.py"],
    { encoding: "utf8" },
  );

  assert.equal(child.status, 0, child.stderr);
  assert.match(child.stdout, /python-child: wsl-direnv/);
  assert.match(child.stdout, /bash-grandchild: wsl-direnv/);
});
