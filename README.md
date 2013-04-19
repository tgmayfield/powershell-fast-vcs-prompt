# Fast VCS prompt for Powershell

To include in your powershell config, just run the included .ps1 file as part of your profile. For example, if I cloned this repository to `<My documents>\WindowsPowershell\powershell-fast-vcs-prompt`, I would add the line:

```Powershell
. ($profileLocation + '.\powershell-fast-vcs-prompt\Prompt.ps1')
```

Any existing customizations to the prompt function will be included (it gets output prior to showing version control information).
