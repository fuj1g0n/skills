using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;

Console.OutputEncoding = new UTF8Encoding(false);

if (args.Length != 2 || args[0] != "-c")
{
    return Fail("Expected the native direnv evaluator contract: -c <script>.");
}

var gitBashPath = Environment.GetEnvironmentVariable("GIT_BASH_PATH");
if (string.IsNullOrWhiteSpace(gitBashPath) || !File.Exists(gitBashPath))
{
    return Fail("GIT_BASH_PATH must name an installed Git Bash executable.");
}

var startInfo = new ProcessStartInfo(gitBashPath)
{
    RedirectStandardOutput = true,
    RedirectStandardError = true,
    StandardOutputEncoding = Encoding.UTF8,
    StandardErrorEncoding = Encoding.UTF8,
    UseShellExecute = false,
};
startInfo.Environment.Remove("PSModulePath");
startInfo.ArgumentList.Add("-c");
startInfo.ArgumentList.Add(args[1]);

using var process = Process.Start(startInfo);
if (process is null)
{
    return Fail("Could not start Git Bash.");
}

var outputTask = process.StandardOutput.ReadToEndAsync();
var errorTask = process.StandardError.ReadToEndAsync();
await process.WaitForExitAsync();
var output = await outputTask;
var error = await errorTask;

if (!string.IsNullOrEmpty(error))
{
    Console.Error.Write(error);
}

if (process.ExitCode != 0)
{
    return process.ExitCode;
}

Dictionary<string, string>? evaluatedEnvironment;
try
{
    evaluatedEnvironment = JsonSerializer.Deserialize<Dictionary<string, string>>(output);
}
catch (JsonException exception)
{
    return Fail($"Git Bash returned invalid environment JSON: {exception.Message}");
}

if (evaluatedEnvironment is null)
{
    return Fail("Git Bash returned an empty environment.");
}

var filteredEnvironment = ReadWindowsEnvironment();
foreach (var (key, value) in evaluatedEnvironment)
{
    if (!key.StartsWith("WSL_DEV_", StringComparison.Ordinal))
    {
        continue;
    }

    if (value.Contains("/nix/store", StringComparison.Ordinal))
    {
        return Fail($"Refusing unsafe metadata in {key}.");
    }

    filteredEnvironment[key] = value;
}

Console.Out.Write(JsonSerializer.Serialize(filteredEnvironment));
return 0;

static int Fail(string message)
{
    Console.Error.WriteLine($"git-bash-filter-adapter: {message}");
    return 1;
}

static Dictionary<string, string> ReadWindowsEnvironment()
{
    var environment = new Dictionary<string, string>(StringComparer.Ordinal);
    var block = GetEnvironmentStringsW();
    if (block == IntPtr.Zero)
    {
        throw new InvalidOperationException("Could not read the Windows environment block.");
    }

    try
    {
        var current = block;
        while (true)
        {
            var entry = Marshal.PtrToStringUni(current);
            if (string.IsNullOrEmpty(entry))
            {
                break;
            }

            var separator = entry.IndexOf('=');
            if (separator >= 0)
            {
                environment[entry[..separator]] = entry[(separator + 1)..];
            }

            current = IntPtr.Add(current, (entry.Length + 1) * sizeof(char));
        }
    }
    finally
    {
        FreeEnvironmentStringsW(block);
    }

    return environment;
}

[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
static extern IntPtr GetEnvironmentStringsW();

[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
[return: MarshalAs(UnmanagedType.Bool)]
static extern bool FreeEnvironmentStringsW(IntPtr environmentBlock);