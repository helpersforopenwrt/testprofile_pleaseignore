param(
    [string]$ThemeRoot = "themes",
    [string]$OutFile = "theme_resources_generated.c"
)

function Escape-CString([string]$Text) {
    return $Text.Replace("\", "\\").Replace('"', '\"')
}

$lines = New-Object System.Collections.Generic.List[string]
$files = @()

if (Test-Path $ThemeRoot) {
    $rootFull = (Resolve-Path $ThemeRoot).Path

    $files = Get-ChildItem -Path $ThemeRoot -File -Recurse | ForEach-Object {
        $full = $_.FullName
        $rel = $full.Substring($rootFull.Length).TrimStart('\', '/').Replace('\', '/')
        $parts = $rel.Split('/')

        if ($parts.Count -ge 2) {
            [PSCustomObject]@{
                FullName = $full
                Theme = $parts[0]
                FileName = ($parts[1..($parts.Count - 1)] -join "/")
            }
        }
    }
}

$themeNames = @()

foreach ($f in $files) {
    if ($themeNames -notcontains $f.Theme) {
        $themeNames += $f.Theme
    }
}

$lines.Add("#include <windows.h>")
$lines.Add("#include ""theme_resources.h""")
$lines.Add("")
$lines.Add("typedef struct ThemeResourceThemeName")
$lines.Add("{")
$lines.Add("    const char *name;")
$lines.Add("} ThemeResourceThemeName;")
$lines.Add("")

$dataNames = @()

for ($i = 0; $i -lt $files.Count; $i++) {
    $dataName = "g_theme_file_data_$i"
    $dataNames += $dataName

    $bytes = [System.IO.File]::ReadAllBytes($files[$i].FullName)

    $lines.Add("static const unsigned char $dataName[] =")
    $lines.Add("{")

    if ($bytes.Length -eq 0) {
        $lines.Add("    0x00")
    } else {
        for ($j = 0; $j -lt $bytes.Length; $j += 16) {
            $end = [Math]::Min($j + 15, $bytes.Length - 1)
            $chunk = $bytes[$j..$end] | ForEach-Object { "0x{0:X2}" -f $_ }
            $lines.Add("    " + ($chunk -join ", ") + ",")
        }
    }

    $lines.Add("};")
    $lines.Add("")
}

$themeCount = $themeNames.Count
$fileCount = $files.Count

$lines.Add("static const int g_themeNameCount = $themeCount;")
$lines.Add("static const int g_themeFileCount = $fileCount;")
$lines.Add("")

$lines.Add("static const ThemeResourceThemeName g_themeNames[] =")
$lines.Add("{")

if ($themeNames.Count -eq 0) {
    $lines.Add("    { NULL }")
} else {
    foreach ($theme in $themeNames) {
        $lines.Add("    { """ + (Escape-CString $theme) + """ },")
    }
}

$lines.Add("};")
$lines.Add("")

$lines.Add("static const ThemeResourceFile g_themeFiles[] =")
$lines.Add("{")

if ($files.Count -eq 0) {
    $lines.Add("    { NULL, NULL, NULL, 0 }")
} else {
    for ($i = 0; $i -lt $files.Count; $i++) {
        $theme = Escape-CString $files[$i].Theme
        $fileName = Escape-CString $files[$i].FileName
        $dataName = $dataNames[$i]
        $size = [System.IO.File]::ReadAllBytes($files[$i].FullName).Length

        $lines.Add("    { ""$theme"", ""$fileName"", $dataName, $size },")
    }
}

$lines.Add("};")
$lines.Add("")

$lines.Add("int ThemeResources_GetThemeCount(void)")
$lines.Add("{")
$lines.Add("    return g_themeNameCount;")
$lines.Add("}")
$lines.Add("")

$lines.Add("const char *ThemeResources_GetThemeName(int index)")
$lines.Add("{")
$lines.Add("    if (index < 0 || index >= ThemeResources_GetThemeCount())")
$lines.Add("        return NULL;")
$lines.Add("")
$lines.Add("    return g_themeNames[index].name;")
$lines.Add("}")
$lines.Add("")

$lines.Add("int ThemeResources_GetFileCount(void)")
$lines.Add("{")
$lines.Add("    return g_themeFileCount;")
$lines.Add("}")
$lines.Add("")

$lines.Add("const ThemeResourceFile *ThemeResources_GetFile(int index)")
$lines.Add("{")
$lines.Add("    if (index < 0 || index >= ThemeResources_GetFileCount())")
$lines.Add("        return NULL;")
$lines.Add("")
$lines.Add("    return &g_themeFiles[index];")
$lines.Add("}")
$lines.Add("")

$lines.Add("const unsigned char *ThemeResources_FindFile(")
$lines.Add("    const char *themeName,")
$lines.Add("    const char *fileName,")
$lines.Add("    unsigned int *size")
$lines.Add(")")
$lines.Add("{")
$lines.Add("    int i;")
$lines.Add("")
$lines.Add("    if (size)")
$lines.Add("        *size = 0;")
$lines.Add("")
$lines.Add("    if (!themeName || !fileName)")
$lines.Add("        return NULL;")
$lines.Add("")
$lines.Add("    for (i = 0; i < ThemeResources_GetFileCount(); i++)")
$lines.Add("    {")
$lines.Add("        if (lstrcmpiA(g_themeFiles[i].themeName, themeName) == 0 &&")
$lines.Add("            lstrcmpiA(g_themeFiles[i].fileName, fileName) == 0)")
$lines.Add("        {")
$lines.Add("            if (size)")
$lines.Add("                *size = g_themeFiles[i].size;")
$lines.Add("")
$lines.Add("            return g_themeFiles[i].data;")
$lines.Add("        }")
$lines.Add("    }")
$lines.Add("")
$lines.Add("    return NULL;")
$lines.Add("}")
$lines.Add("")

[System.IO.File]::WriteAllLines($OutFile, $lines)