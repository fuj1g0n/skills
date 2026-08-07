using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

const string stdlibInvocationPrefix = "eval \"$(\"";
const string stdlibInvocationSuffix = "\" stdlib)\"";

Console.OutputEncoding = new UTF8Encoding(false);

if (args.Length != 2 || args[0] != "-c")
{
    return Fail("Expected the native direnv evaluator contract: -c <script>.");
}

var distribution = Environment.GetEnvironmentVariable("WSL_DEV_DISTRO");
if (string.IsNullOrWhiteSpace(distribution))
{
    return Fail("WSL_DEV_DISTRO must name the target WSL distribution.");
}

var configDirectory = Environment.GetEnvironmentVariable("DIRENV_CONFIG");
if (string.IsNullOrWhiteSpace(configDirectory))
{
    return Fail("DIRENV_CONFIG must be an explicit Windows path.");
}

string workingDirectory;
string wslConfigDirectory;
try
{
    workingDirectory = ToWslPath(Environment.CurrentDirectory);
    wslConfigDirectory = ToWslPath(configDirectory);
}
catch (ArgumentException exception)
{
    return Fail(exception.Message);
}

var script = args[1];
var invocationStart = script.IndexOf(stdlibInvocationPrefix, StringComparison.Ordinal);
var invocationEnd = script.IndexOf(stdlibInvocationSuffix, StringComparison.Ordinal);
if (invocationStart < 0 || invocationEnd <= invocationStart)
{
    return Fail("The evaluator script did not contain the expected direnv stdlib invocation.");
}

invocationEnd += stdlibInvocationSuffix.Length;
script = string.Concat(
    script.AsSpan(0, invocationStart),
    "eval \"$(direnv stdlib)\"",
    script.AsSpan(invocationEnd));
script = Regex.Replace(
    script,
    "(?i)([a-z]):/",
    match => $"/mnt/{match.Groups[1].Value.ToLowerInvariant()}/");

var shellInput = $"""
    export DIRENV_CONFIG={BashQuote(wslConfigDirectory)}
    export WSL_DEV_DISTRO={BashQuote(distribution)}
    {script}
    """.Replace("\r\n", "\n", StringComparison.Ordinal);

var startInfo = new ProcessStartInfo("wsl.exe")
{
    RedirectStandardInput = true,
    RedirectStandardOutput = true,
    RedirectStandardError = true,
    StandardOutputEncoding = Encoding.UTF8,
    StandardErrorEncoding = Encoding.UTF8,
    UseShellExecute = false,
};
startInfo.ArgumentList.Add("--distribution");
startInfo.ArgumentList.Add(distribution);
startInfo.ArgumentList.Add("--cd");
startInfo.ArgumentList.Add(workingDirectory);
startInfo.ArgumentList.Add("--exec");
startInfo.ArgumentList.Add("bash");
startInfo.ArgumentList.Add("-lc");
startInfo.ArgumentList.Add("exec bash -s");

using var process = Process.Start(startInfo);
if (process is null)
{
    return Fail("Could not start wsl.exe.");
}

await process.StandardInput.WriteAsync(shellInput);
process.StandardInput.Close();
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
    return Fail($"WSL evaluator returned invalid environment JSON: {exception.Message}");
}

if (evaluatedEnvironment is null)
{
    return Fail("WSL evaluator returned an empty environment.");
}

if (evaluatedEnvironment.TryGetValue("PATH", out var evaluatedPath) &&
    evaluatedPath.Contains("/nix/store", StringComparison.Ordinal))
{
    return Fail("Refusing a WSL evaluator result whose PATH contains /nix/store.");
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
    Console.Error.WriteLine($"wsl-bash-adapter: {message}");
    return 1;
}

static string ToWslPath(string windowsPath)
{
    var fullPath = Path.GetFullPath(windowsPath);
    if (fullPath.Length < 3 || fullPath[1] != ':' ||
        (fullPath[2] != '\\' && fullPath[2] != '/'))
    {
        throw new ArgumentException($"Only drive-rooted Windows paths are supported: {windowsPath}");
    }

    var drive = char.ToLowerInvariant(fullPath[0]);
    var remainder = fullPath[3..].Replace('\\', '/');
    return string.IsNullOrEmpty(remainder) ? $"/mnt/{drive}" : $"/mnt/{drive}/{remainder}";
}

static string BashQuote(string value)
{
    return $"'{value.Replace("'", "'\\''", StringComparison.Ordinal)}'";
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