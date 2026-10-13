#Requires -Version 5.1
# Codex Auto Retry v4. READ ONLY: discovers capacity errors and Retry via UIA.
# Never invokes, clicks, activates, focuses or sends input.
param(
    [Parameter(Mandatory=$true)][long]$Handle,
    [ValidateSet('test')][string]$Mode = 'test',
    [Parameter(Mandatory=$true)][string]$OutFile
)

$ErrorActionPreference = 'Stop'
$result = 'UIA_ERROR|Unknown error'

try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes

    # Bind exclusively to HWND given by AHK (rather than the foreground app).
    $root = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]::new($Handle))
    if ($null -eq $root) {
        $result = 'WINDOW_GONE|Invalid window handle'
    } else {
        $scope = [System.Windows.Automation.TreeScope]::Descendants
        $nameProp = [System.Windows.Automation.AutomationElement]::NameProperty
        $retryCondition = [System.Windows.Automation.PropertyCondition]::new($nameProp, 'Retry')
        $retryElements = $root.FindAll($scope, $retryCondition)
        $buttons = New-Object 'System.Collections.Generic.List[System.Windows.Automation.AutomationElement]'

        for ($i = 0; $i -lt $retryElements.Count; $i++) {
            $element = $retryElements[$i]
            try {
                $current = $element.Current
                $rect = $current.BoundingRectangle
                if ($current.IsEnabled -and -not $current.IsOffscreen -and
                    $rect.Width -gt 2 -and $rect.Height -gt 2 -and
                    $current.ControlType -eq [System.Windows.Automation.ControlType]::Button) {
                    $buttons.Add($element)
                }
            } catch { }
        }

        if ($buttons.Count -eq 0) {
            $result = 'NO_BUTTON|Chromium did not expose a visible enabled button named Retry.'
        } else {
            $errors = New-Object 'System.Collections.Generic.List[System.Windows.Automation.AutomationElement]'
            $seen = @{}
            foreach ($candidateName in @(
                'Selected model is at capacity. Please try a different model.',
                'Selected model is at capacity.',
                'Selected model is at capacity'
            )) {
                $errorCondition = [System.Windows.Automation.PropertyCondition]::new($nameProp, $candidateName)
                $found = $root.FindAll($scope, $errorCondition)
                for ($i = 0; $i -lt $found.Count; $i++) {
                    $item = $found[$i]
                    try {
                        $rect = $item.Current.BoundingRectangle
                        $key = ('{0:N0}/{1:N0}/{2:N0}' -f $rect.X, $rect.Y, $rect.Height)
                        if ($rect.Width -gt 3 -and $rect.Height -gt 2 -and -not $seen.ContainsKey($key)) {
                            $errors.Add($item)
                            $seen[$key] = $true
                        }
                    } catch { }
                }
            }

            # Chromium may include the warning in a longer accessible label.
            # This fallback is more expensive, only used when exact lookup fails.
            if ($errors.Count -eq 0) {
                $all = $root.FindAll($scope, [System.Windows.Automation.Condition]::TrueCondition)
                for ($i = 0; $i -lt $all.Count; $i++) {
                    $item = $all[$i]
                    try {
                        $name = $item.Current.Name
                        if ($name -and $name.IndexOf('Selected model is at capacity', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                            $rect = $item.Current.BoundingRectangle
                            if ($rect.Width -gt 3 -and $rect.Height -gt 2) {
                                $errors.Add($item)
                            }
                        }
                    } catch { }
                }
            }

            if ($errors.Count -eq 0) {
                $result = 'NO_ERROR|No capacity warning found in VS Code UI Automation tree.'
            } else {
                $target = $null
                $bestScore = [double]::PositiveInfinity
                foreach ($btn in $buttons) {
                    try {
                        $br = $btn.Current.BoundingRectangle
                        $bCenterY = $br.Y + $br.Height / 2
                        foreach ($err in $errors) {
                            try {
                                $er = $err.Current.BoundingRectangle
                                $eCenterY = $er.Y + $er.Height / 2
                                $dy = [Math]::Abs($bCenterY - $eCenterY)
                                # Keep the button on the warning's row and to its right.
                                $tolerance = [Math]::Max(30, [Math]::Max($er.Height, $br.Height) * 1.4)
                                if ($dy -le $tolerance -and $br.X -gt $er.X + 8 -and $dy -lt $bestScore) {
                                    $bestScore = $dy
                                    $target = $btn
                                }
                            } catch { }
                        }
                    } catch { }
                }

                if ($null -eq $target) {
                    $result = 'NO_MATCH|Warning text and button were exposed but not vertically aligned.'
                } else {
                    # READ-ONLY: ControlClick will target the matched location.
                    # No InvokePattern is required for this mode.
                    $rect = $target.Current.BoundingRectangle
                    $x = [int][Math]::Round(($rect.X + $rect.Width / 2))
                    $y = [int][Math]::Round(($rect.Y + $rect.Height / 2))
                    $result = ('FOUND|x={0}|y={1}|w={2}|h={3}' -f $x, $y, [int]$rect.Width, [int]$rect.Height)
                }
            }
        }
    }
} catch {
    $message = ($_.Exception.Message -replace '[\r\n]+', ' ').Trim()
    if ($message.Length -gt 220) { $message = $message.Substring(0, 220) }
    $result = 'UIA_ERROR|' + $message
} finally {
    try {
        [System.IO.File]::WriteAllText($OutFile, $result, ([System.Text.UTF8Encoding]::new($false)))
    } catch { }
}