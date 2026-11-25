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

	[void] Output()
	{
		Write-Host "" # Force a newline
		Write-Host -NoNewLine "  "
		Write-Host -NoNewLine -ForegroundColor DarkYellow $this.Location
		if ($this.Commit)
		{
			Write-Host -NoNewLine -ForegroundColor Magenta " changed commit"
		}
		if ($this.TrackedChanges)
		{
			Write-Host -NoNewLine -ForegroundColor Green " changes"
		}
		if ($this.UntrackedChanges)
		{
			Write-Host -NoNewLine -ForegroundColor DarkGreen " extra files"
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

	[void] ParsePorcelain([string]$line)
	{
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
		Write-Host -NoNewLine -ForegroundColor Yellow $this.Branch
		if ($this.Delta)
		{
			Write-Host -NoNewLine -ForegroundColor DarkMagenta " ("
			Write-Host -NoNewLine -ForegroundColor Magenta $this.Delta
			Write-Host -NoNewLine -ForegroundColor DarkMagenta ")"
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
		$status | foreach {
			$line = $_
			if ($line.StartsWith("# branch.head "))
			{
				$counts.Branch = $line.Substring("# branch.head ".Length)
			}
			elseif ($line.StartsWith("# branch.oid "))
			{
				$counts.Commit = $line.Substring("# branch.oid ".Length)
			}
			elseif ($line.StartsWith("# branch.upstream "))
			{
			}
			elseif ($line.StartsWith("# branch.ab "))
			{
				$counts.Delta = $line.Substring("# branch.ab ".Length).Replace(" ", "").Replace("-0", "")
				if ($counts.Delta -Eq "+0")
				{
					$counts.Delta = "~"
				}
			}
			else
			{
				$counts.ParsePorcelain($line)
			}
		}
		if ($counts.Branch -eq "(detached)")
		{
			$counts.Branch = "detached:" + $oid.Substring(0, 11)
		}
		git tag --points-at HEAD | foreach {
			$counts.Tags += $_
		}
		$counts.Output()
		Write-Host ""
	}

	writeGitStatusNew
	& $oldPrompt
	$LASTEXITCODE = $realLASTEXITCODE
	return $ending
}
