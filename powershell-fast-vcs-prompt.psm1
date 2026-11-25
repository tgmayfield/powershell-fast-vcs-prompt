class StatusCounter
{
	[int]$Staged
	[int]$Unstaged

	[void] Output($marker)
	{
		if ($this.Staged -Or $this.Unstaged)
		{
			Write-Host -NoNewLine -ForegroundColor DarkGreen (" " + $marker + ":")
			Write-Host -NoNewLine -ForegroundCOlor Green $this.Staged
			if ($this.Unstaged)
			{
				Write-Host -NoNewLine -ForegroundColor DarkGreen "/"
				Write-Host -NoNewLine -ForegroundColor Green $this.Unstaged
			}
		}
	}
}
class SubmoduleStatus
{
	[string]$Location
	[bool]$Commit
	[bool]$TrackedChanges
	[bool]$UntrackedChanges
	[Statuses]$Details

	[void] Output()
	{
		Write-Host "" # Force a newline
		Write-Host -NoNewLine "  "
		Write-Host -NoNewLine -ForegroundColor DarkYellow $this.Location
		if ($this.Commit)
		{
			Write-Host -NoNewLine -ForegroundColor DarkGray ", "
			Write-Host -NoNewLine -ForegroundColor Magenta "changed commit"
		}
		if ($this.TrackedChanges)
		{
			Write-Host -NoNewLine -ForegroundColor DarkGray ", "
			Write-Host -NoNewLine -ForegroundColor Green "changes"
		}
		if ($this.UntrackedChanges)
		{
			Write-Host -NoNewLine -ForegroundColor DarkGray ", "
			Write-Host -NoNewLine -ForegroundColor DarkGreen "extra files"
		}

		if ($this.Details)
		{
			Write-Host -NoNewLine -ForegroundColor DarkGray ", "
			$this.Details.Output()
		}
	}
}
class Statuses
{
	Statuses()
	{
		$this.Updated = [StatusCounter]::new()
		$this.Deleted = [StatusCounter]::new()
		$this.Added = [StatusCounter]::new()
	}

	[string]$Branch
	[string]$Commit
	[string]$Delta
	[string[]]$Tags = @()
	[StatusCounter]$Updated
	[StatusCounter]$Added
	[StatusCounter]$Deleted
	[SubmoduleStatus[]] $Submodules = @()

	[void] LoadTags()
	{
		git tag --points-at HEAD | foreach {
			$this.Tags += $_
		}
	}

	[void] LoadStatus()
	{
		git status --porcelain=2 --branch 2>&1 | foreach {
			$this.ParsePorcelain($_)
		}
	}

	[void] ParsePorcelain([string]$line)
	{
		if ($line.StartsWith("# branch.head "))
		{
			$this.Branch = $line.Substring("# branch.head ".Length)
			return
		}
		if ($line.StartsWith("# branch.oid "))
		{
			$this.Commit = $line.Substring("# branch.oid ".Length)
			return
		}
		if ($line.StartsWith("# branch.upstream "))
		{
			# Ignored
			return
		}
		if ($line.StartsWith("# branch.ab "))
		{
			$this.Delta = $line.Substring("# branch.ab ".Length).Replace(" ", "").Replace("-0", "")
			if ($this.Delta -Eq "+0")
			{
				$this.Delta = "~"
			}
			return
		}

		if ($line[0] -Eq "?")
		{
			$this.Added.Unstaged++
			return
		}
		if ($line[5] -Eq "S")
		{
			$sub = [SubmoduleStatus]::new()
			$sub.Location = $line.Substring(113)
			$sub.Commit = $line[6] -Eq "C"
			$sub.TrackedChanges = $line[7] -Eq "M"
			$sub.UntrackedChanges = $line[8] -Eq "U"
			$this.Submodules += $sub
			return
		}
		$staged = $line[2]
		$unstaged = $line[3]
		switch ($staged)
		{
			"M" { $this.Updated.Staged++ }
			"A" { $this.Added.Staged++ }
			"D" { $this.Deleted.Staged++ }
		}
		switch ($unstaged)
		{
			"M" { $this.Updated.Unstaged++ }
			"D" { $this.Deleted.Unstaged++ }
		}
	}

	[void] Output()
	{
		if ($this.Branch -Or $this.Commit)
		{
			$b = $this.Branch
			if ($b -eq "(detached)")
			{
				$b = "detached:" + $this.Commit.Substring(0, 11)
			}
			Write-Host -NoNewLine -ForegroundColor Yellow $b
		}
		if ($this.Delta)
		{
			$light = [System.ConsoleColor]::Magenta
			if ($this.Delta -Eq "~")
			{
				$light = [System.ConsoleColor]::DarkMagenta
			}
			Write-Host -NoNewLine -ForegroundColor $light $this.Delta
		}
		$this.Updated.Output("u")
		$this.Added.Output("a")
		$this.Deleted.Output("d")
		if ($this.Tags)
		{
			foreach ($tag in $this.Tags)
			{
				Write-Host -NoNewLine -ForegroundColor DarkGray ", "
				Write-Host -NoNewLine -ForegroundColor DarkYellow $tag
			}
		}
		foreach ($sub in $this.Submodules)
		{
			$sub.Output()
		}
	}
}

if (test-path function:\prompt) {
	$oldPrompt = ls function: | ? {$_.Name -eq "prompt"}
	remove-item -force function:\prompt
}
function prompt {
	$realLASTEXITCODE = $LASTEXITCODE
	$command = $$

	function writeGitStatusNew
	{
		if (-Not (Get-Command "git" -ErrorAction Ignore))
		{
			return
		}
		$status = git status --porcelain=2 --branch 2>&1
		if ($LASTEXITCODE -eq 128)
		{
			$error.clear()
			return
		}
		if ($status.Exception -ne $null)
		{
			if ($LASTEXITCODE -ne 255)
			{
				$error.clear()
				return
			}
		}

		$counts = [Statuses]::new()
		$counts.LoadStatus()
		$counts.LoadTags()

		$loadSubDetails = $true # TODO: I'd prefer to only load submodule details when the user just presses enter and does not run any commands. $$ doesn't seem to work within the prompt function
		if ($loadSubDetails)
		{
			foreach ($submodule in $counts.Submodules)
			{
				pushd $submodule.Location
				try
				{
					$submodule.Details = [Statuses]::new()
					$submodule.Details.LoadStatus()
					$submodule.Details.LoadTags()
				}
				finally
				{
					popd
				}
			}
		}

		$counts.Output()
		Write-Host ""
	}

	writeGitStatusNew
	& $oldPrompt
	$LASTEXITCODE = $realLASTEXITCODE
	return $ending
}
