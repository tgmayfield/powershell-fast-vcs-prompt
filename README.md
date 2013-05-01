# Fast VCS prompt for Powershell

To include in your powershell config, clone the repository to your Powershell Modules directory (`<My documents>\WindowsPowershell\Modules\powershell-fast-vcs-prompt`) and then import the module:

```Powershell
Import-Module Powershell-Fast-VCS-Prompt
```

Any existing customizations to the prompt function will be included (it gets output prior to showing version control information). The `Import-Module` directive should occur after your custom prompt function.

By default, it will show your current prompt, then show:

    (<branch name><+num_ahead_tracked><-num_behind_tracked> a:<addded_to_index> u:<updates_in_index>/<updates_not_in_index> d:<deletes_in_index>/<deletes_not_in_index> ?:<untracked>)

Any section without data isn't displayed. So, if you're on master with 2 new files (1 indexed), 3 updates (2 indexed), and have 3 changes to push to remote, you would see:

    (master+3 a:1/1 u:2/1)

For subversion, any change in a change list is listed in parentheses after its main number.
