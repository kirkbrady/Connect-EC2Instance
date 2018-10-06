Function Connect-EC2Instance{
    
    <#
    .SYNOPSIS
        Connects to EC2 instances in AWS without needing to decrypt the password manually using a pem file.

    .DESCRIPTION
        Automatically figues out password for instance if the pem file is found, and connects via RDP.
        Assumes development environment with AWS default profile name "dev".
        Looks to default path in your documents for pem files under $environment directory.
        You can specify path and file name of pem if needed.
    
    .PARAMETER InstanceId
        The AWS Id of the instance.
    
    .PARAMETER Environment
        The AWS profile name, usually mapped to an environment name.
    
    .PARAMETER KeyName
        If not gotten from the properties of the EC2 instance, the pem key file name.
    
    .PARAMETER KeyPath
        The path to the pem key file name.

    .PARAMETER Username
        The Username to use to log on to the EC2 instance if not the default 'Administrator'.

    .PARAMETER Region
        The AWS region to use - defaults to ap-southeast-2.

    .PARAMETER Protocol
        The protocol to connect with - can be RDP or SSH.
    
    .EXAMPLE
        Connect-Ec2instance i-12345678

        No arguments given. Assumes "dev" AWS profile. Figures out pem key name from EC2 instance properties.
    
    .EXAMPLE
        Connect-Ec2instance i-12345678 -Environment production

        Connects to EC2 instance in the "production" AWS profile.  Figures out pem key name from EC2 instance properties.
    
    .EXAMPLE
        Connect-Ec2instance i-12345678 -Environment production -KeyName myproductionpem.pem -KeyPath c:\super\secret\path

        Specify pem key filename and path, if not defaults.

    .EXAMPLE
        Connect-EC2Instance i-12345678 -Username DifferentAdministrator -KeyName myproductionpem.pem -KeyPath c:\super\secret\path

        Specify non default username to connect with. Specify pem key filename and path, if not defaults.

    .EXAMPLE
        Connect-EC2Instance -Protocol ssh -port 22 -InstanceIds i-12345678 -Environment production -KeyName myproductionpem.pem -KeyPath c:\super\secret\path -Username ec2-user

        Connect via SSH on port 22. Uses the "production" AWS environment.Specifies pem key filename and path. Specifies username to connect with.

    .NOTES
        Written to work with Jaap Brasser's Connect-Mstsc function - https://gallery.technet.microsoft.com/scriptcenter/Connect-Mstsc-Open-RDP-2064b10b

        Author: Kirk Brady
        Site: https://github.com/kirkbrady
 
        Version History
        1.0.2 - Enhancements to InstanceIds array support.
                Added support for SSH protocol connections.
    #>

    [CmdletBinding()]

    Param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
        [Alias("Instances","Computers","ComputerNames","MachineNames","PrivateIpAddress")]
            [string[]]$InstanceIds,
        [Parameter(Mandatory=$false,Position=1)]
        [Alias("Env","Profile","ProfileName")]
            [string]$Environment="dev",
        [Parameter(Mandatory=$false,Position=2)]
        [Alias("Key","Pem")]
            [string]$KeyName,
        [Parameter(Mandatory=$false,Position=3)]
        [Alias("Path","PemPath")]
            [string]$KeyPath="$env:USERPROFILE\Documents\pem\$Environment",
        [Parameter(Mandatory=$false,Position=4)]
        [Alias("User")]
            [string]$Username="Administrator",
        [Parameter(Mandatory=$false,Position=5)]
            [string]$Region="ap-southeast-2",
        [Parameter(Mandatory=$false,Position=6)]
        [ValidateSet(“SSH”,”RDP”)]
        [Alias("ConnectWith","ConnectionType","Connection")]
            [string]$Protocol="RDP",
        [Parameter(Mandatory=$false,Position=7)]
            [string]$Port="3389"
    )
    Begin {
        If(Initialize-AWSDefaults -ProfileName $Environment -Region $Region){
            Write-Output "Initialized AWS defaults for environment `"$Environment`"."
            }
        }

    Process {
        Try {
            Foreach($InstanceId in $InstanceIds){

                If(!$KeyName){
                    [string]$KeyName=(Get-EC2Instance -InstanceId $InstanceId).Instances.Keyname
                }

                $PemFile = (gci $Keypath\* -include *.pem| where {$_.name -match $keyname}).FullName


                if($PemFile){
                    If(Test-Path $Pemfile){
                        
                        $PrivateIP = (Get-EC2Instance $InstanceId).RunningInstance.PrivateIpAddress;

                        If(!$PrivateIP){
                            Throw "Could not obtain private ip value for $InstanceId."
                        }

                        if(!((Get-EC2Instance -InstanceId $InstanceId).Instances.Platform.Value -eq "windows")){
                            $Protocol = "SSH";
                            $Port = 22;

                            $Ami = (Get-EC2Instance -InstanceId $InstanceId).Instances.ImageId
                            $Platform = (Get-EC2Image -ImageId $Ami).Name

                            Switch -wildcard ($Platform){
                                "ubuntu*" { $Username = "ubuntu" }
                                default { $Username = "ec2-user" }
                            }
                        }

                        Write-Output "Connecting to instance $InstanceId in environment $Environment on IP $PrivateIP using $Protocol on platform $Platform."
                        Write-Output "Target PEM file is $PemFile.`n"

                        Switch($Protocol){
                            "RDP" {                                    
                                    $Pass = Get-EC2PasswordData -InstanceId $InstanceId -PemFile $PemFile -Decrypt;
                                    Connect-Mstsc -computername $PrivateIP -password $Pass -user $Username -fullscreen;
                                }
                            
                            "SSH" {
                                    start-process ssh -ArgumentList @("-i", "$PemFile" ,"$Username@$PrivateIP", "-p $Port")
                                }
                        }

                    }
                } else {
                   Throw "PEM file value is invalid - please check."
                }
            }
        }
        Catch {
            $_.Exception
        }
    }
    
    End {
    }
}
