#===========================================================================
# Global variables
#===========================================================================
Clear-Host
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
#read XML configs and Frontend UI
$inputXML = get-content "$scriptdir\MainWindow.xaml"      
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N'  -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
try {
    $Form=[Windows.Markup.XamlReader]::Load( $reader )
}
catch{
    Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."
}

#===========================================================================
# Load Task Sequence environment and variables
#===========================================================================
try 
{
	$TSProgressUI = new-object -comobject Microsoft.SMS.TSProgressUI
	$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
}
catch 
{
	Write-Host "== Task sequence environment [PE] not found" -ForegroundColor yellow
}
$sitecode = $tsenv.value("_SMSTSSiteCode")
$siteserver = $tsenv.value("TSsiteserver")
$uconlist = $userconfig.settings.collection
$domainname = $tsenv.value("TSdomainname")
$domainsuffix = $tsenv.value("TSdomainsuffix")
$bootstatus = $tsenv.value("_SMSTSBootUEFI")
$validOU = ""
$SecretKey = "<WEBSERVICESECRETKEY>"
$WMIcomputer = Get-WmiObject -Class Win32_computersystem
$WMIBios = Get-WmiObject -Class Win32_BIOS
$PackageEnumerate = @()
$ApplicationEnumerate = @()
$alldomains = @()
$exdom = new-object PSObject -Property @{name = "DomainLoc1" ;path = "OU=Byod,DC=domain,DC=LOCAL";type = "Byod";Domeinnaam = "domain.local"}
$alldomains += $exdom
$exdom = new-object PSObject -Property @{name = "Domainloc2" ;path = "OU=Workstations,DC=domain,DC=LOCAL";type = "Managed";Domeinnaam = "domain.local"}
$alldomains += $exdom

#===========================================================================
# Webservice init
#===========================================================================
# Construct web service proxy
try 
{
    $URI = "http://sc01.domain.local/ConfigMgrWebService/ConfigMgr.asmx"
    $WebService = New-WebServiceProxy -Uri $URI -ErrorAction Stop
}
catch [System.Exception] 
{
    Write-Warning -Message "An error occured while attempting to calling web service. Error message: $($_.Exception.Message)" ; exit 2
}
#===========================================================================
# Functions
#===========================================================================

#===========================================================================
# F01 - Load XAML Objects In PowerShell
#===========================================================================
$xaml.SelectNodes("//*[@Name]") | %{Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}

Function Get-FormVariables 
{
    if ($global:ReadmeDisplay -ne $true) 
    {
        Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;$global:ReadmeDisplay=$true
    }
    write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
    get-variable WPF*
}

#===========================================================================
# F02 - enumerate Organizational Units
#===========================================================================
function Enum-OU(
    [string]$rootOU
)
{
    $oulist = @()
    $level1 = $WebService.GetADOrganizationalUnits($SecretKey,$rootOU)
    foreach ($1 in $level1)
    {
        $l1label = $1.name
        $l1dn = $($1.DistinguishedName).SubString(7)
        #write-host "name = $($1.name) ;path = $l1dn;type = $($1.name);subtype = "";parent = " -ForegroundColor green
        #$row = new-object PSObject -Property @{name = $1.name ;path = $l1dn;type = $1.name;subtype = "";parent = ""}
        #$oulist += $row 
        if ($1.HasChildren -eq $true)
        {
            $level2 = $WebService.GetADOrganizationalUnits($SecretKey,$l1dn)  
            foreach ($2 in $level2)
            {
                $l2label = $2.name
                $l2dn = $($2.DistinguishedName).SubString(7)
                #write-host "name = $($1.name) ;path = $l2dn;type = $($2.name);subtype = "";parent = $($1.name)" -ForegroundColor cyan    
                $row = new-object PSObject -Property @{name = $2.name ;path = $l2dn;type = $2.name;subtype = "";parent = $1.name}
                $oulist += $row
                if ($2.HasChildren -eq $true)
                {
                    $level3 = $WebService.GetADOrganizationalUnits($SecretKey,$l2dn)  
                    foreach ($3 in $level3)
                    {
                        $l3label = $3.name
                        $l3dn = $($3.DistinguishedName).SubString(7)
                        #write-host "name = $($3.name) ;path = $l3dn;type = $($3.name);subtype = "";parent = $($1.name) \ $($2.name)" -ForegroundColor magenta
                        $parent = "$($1.name) \ $($2.name)"
                        $row = new-object PSObject -Property @{name = $3.name ;path = $l3dn;type = $3.name;subtype = "";parent = $parent}
                        $oulist += $row    
                    }
                }
            }
        }
    }
    
    return $oulist
}

#===========================================================================
# Form
#===========================================================================
#Vullen OS keuzelijst uit XML waarden
foreach ($dom in $alldomains){
    $WPF_cb_osselection.AddChild($dom.name)
}
$form.Add_loaded({
    $WPF_cb_dptype.Items.Clear()
    $WPF_cb_locationsel.Items.Clear()
    try 
    {
        $WPF_tb_devname.Text = $tsenv.Value("_SMSTSMachineName")
    }
    catch 
    {
        $WPF_tb_devname.Text = "Computernaam"
    }
    $WPF_img_logo.Source = $scriptDir + "\images\default.png"
    $WPF_lb_info_hw.Content = $WMIcomputer.Model + " / "+$WMIBios.SerialNumber
    $WPF_lb_info_hw_man.Content = $WMIcomputer.Manufacturer
    If ($bootstatus -eq "true") 
    {
		$WPF_lb_info_uefi.Content = "UEFI"
	} 
    else 
    {
		$WPF_lb_info_uefi.Content = "BIOS"
	}
    #get known device name
    $localmacs = Get-WmiObject win32_networkadapterconfiguration | select macaddress
    foreach ($m in $localmacs) 
    {
    if ($m.macaddress) 
        {
            $WPF_lb_info_mac.Content = $m.macaddress
            $maddress = $m.macaddress
            try 
            {
                $name = $WebService.GetCMDeviceNameByMACAddress($SecretKey,$maddress)
                if (($name -like "Unknown") -or (!$name)) 
                {
                    $WPF_tb_devname.Text = "Computernaam"
                    $knowncomputer = $false
                } 
                else 
                {
                    $WPF_tb_devname.Text = $name
                    $WPF_tb_devname.IsReadOnly = "True"
                    $knowncomputer = $true
                    $tsenv.Value("OSDComputerName") = $name
                    $form.Close()
                }
                write-host $name -ForegroundColor Yellow
            }
            catch
            {
            }
        }
        if (!$m.macaddress) 
        {
            write-host "Geen MAC adres..."
        }          
    }
})
$WPF_cb_osselection.Add_DropDownClosed({
    $containerloc = $WPF_cb_osselection.Text
    $WPF_cb_dptype.Items.Clear()
    $WPF_cb_locationsel.Items.Clear()
    foreach ($domain in $alldomains)
    {
        if ($domain.name -eq $containerloc)
        {
            $LocBaseOU = $domain.path
            write-host $LocBaseOU -ForegroundColor Magenta
        }
    }
    $oulisting = Enum-OU -rootOU $LocBaseOU
    $uoul = $oulisting.type
    $uoul = $uoul | Select-Object -Unique
    $WPF_cb_locationsel.Items.Clear()
    foreach ($loccol in $oulisting) 
    {
        $loc = "$($loccol.parent) \ $($loccol.name)"
        $WPF_cb_locationsel.AddChild($loc)
    } 
})
$WPF_cb_locationsel.Add_Dropdownclosed({            
    $locationsel = $WPF_cb_locationsel.Text  
})

#===========================================================================
# Acties bij afronden / ok 
#===========================================================================
$WPF_bt_ok.add_CLick({
    $containerloc = $WPF_cb_osselection.Text
    foreach ($domain in $alldomains)
    {
        if ($domain.name -eq $containerloc)
        {
            $LocBaseOU = $domain.path
            $Domeinnaam = $domain.domeinnaam
            write-host $LocBaseOU -ForegroundColor Magenta
        }
    }
    $oulisting = Enum-OU -rootOU $LocBaseOU
    foreach ($oul in $oulisting)
    { 
        $locvar = "$($oul.parent) \ $($oul.name)"
        if ($locvar -eq $WPF_cb_locationsel.text)
        {
            $Locname = $oul.name
            $OULocation = $oul.path
        }
    }
    write-host $domeinnaam, $oulocation -ForegroundColor Cyan
    write-host $Locname -ForegroundColor Cyan
    $TSenv.Value("OSDDomainOUName") = $OULocation
    $TSenv.Value("OSDDomainName") = $Domeinnaam
    write-host $tsenv.Value("OSDDomainOUName") -ForegroundColor Yellow
    write-host $TSenv.Value("OSDDomainName") -ForegroundColor Yellow 

	try
    {
        $tsenv.Value("OSDComputerName") = $WPF_tb_devname.Text
    }
	catch
	{
		Write-Host "-" -ForegroundColor yellow
	}
    $form.Close()
})

#===========================================================================
# Start form and Task Sequence actions. 
#===========================================================================
try 
{
    $TSProgressUI.CloseProgressDialog()
}
catch
{
}
$form.ShowDialog() 