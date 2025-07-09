param(
    [int]$Minutes = 30
)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# --- CONFIGURATION ---
[TimeSpan]$TotalDuration = [TimeSpan]::FromMinutes($Minutes)
[TimeSpan]$WarningAt     = [TimeSpan]::FromMinutes(2)
[int]      $FormWidth     = 300
[int]      $FormHeight    = 100
[string]   $FontName      = 'Consolas'
[int]      $FontSizeMain  = 24
[int]      $FontSizeWarn  = 10
$ColorMain  = [Drawing.Color]::Lime
$ColorWarn  = [Drawing.Color]::Red
[string]   $WarningText   = "The session will sign out shortly"
[int]      $LoopSleepMs   = 200
[int]      $Margin        = 5   # pixels between countdown and warning
# ----------------------

# Create the form
$form = New-Object System.Windows.Forms.Form -Property @{
    Width           = $FormWidth
    Height          = $FormHeight
    FormBorderStyle = 'None'
    ControlBox      = $false
    StartPosition   = 'Manual'
    TopMost         = $true
    BackColor       = [Drawing.Color]::Magenta
    TransparencyKey = [Drawing.Color]::Magenta
}
$form.ShowInTaskbar = $false

# Position at ~80% width, ~85% height of primary screen
$screen = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Left = [int]($screen.Width  * 0.80)
$form.Top  = [int]($screen.Height * 0.85)

# Main countdown label
$lbl = New-Object System.Windows.Forms.Label
$lbl.Font      = New-Object Drawing.Font($FontName, $FontSizeMain)
$lbl.ForeColor = $ColorMain
$lbl.BackColor = [Drawing.Color]::Transparent
$lbl.AutoSize  = $true
$form.Controls.Add($lbl)

# Warning label
$warn = New-Object System.Windows.Forms.Label
$warn.Font      = New-Object Drawing.Font($FontName, $FontSizeWarn)
$warn.ForeColor = $ColorWarn
$warn.BackColor = [Drawing.Color]::Transparent
$warn.AutoSize  = $true
$warn.Visible   = $false
$form.Controls.Add($warn)

function Center-ControlHorizontally {
    param([System.Windows.Forms.Control]$ctrl)
    $ctrl.Left = [int](($form.ClientSize.Width - $ctrl.PreferredWidth) / 2)
}

# Show form (so transparency takes effect)
$form.Show()

# Calculate end time
$endTime = (Get-Date).Add($TotalDuration)

while ($true) {
    $now       = Get-Date
    $remaining = $endTime - $now

    if ($remaining.TotalSeconds -le 0) { break }

    # Update countdown
    $lbl.Text = $remaining.ToString('m\:ss')
    Center-ControlHorizontally $lbl
    # Vertically center the countdown label
    $lbl.Top = [int](($form.ClientSize.Height - $lbl.PreferredHeight - $warn.PreferredHeight - $Margin) / 2)

    # Enter warning phase
    if ($remaining -le $WarningAt) {
        $warn.Text  = $WarningText
        Center-ControlHorizontally $warn
        # Place warning below the countdown
        $warn.Top   = $lbl.Bottom + $Margin
        $warn.Visible = $true

        # Change countdown color as well
        $lbl.ForeColor = [Drawing.Color]::Red
    }

    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds $LoopSleepMs
}

$form.Close()
