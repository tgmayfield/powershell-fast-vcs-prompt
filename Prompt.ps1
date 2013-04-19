Add-Type @'
	using System;
	using System.Collections.Generic;
	using System.Linq;
	using System.Text;

	public class EnabledContainer
	{
		public EnabledContainer()
		{
		}

		public EnabledContainer(bool enabled)
		{
			Enabled = enabled;
		}

		public virtual bool Enabled { get; set; }

		public static readonly EnabledContainer Always = new EnabledContainer()
		{
			Enabled = true,
		};
	}

	public class ReverseEnabledContainer
		: EnabledContainer
	{
		private readonly EnabledContainer _source;

		public ReverseEnabledContainer(EnabledContainer source)
		{
			_source = source;
		}

		public override bool Enabled
		{
			get { return !_source.Enabled; }
			set { _source.Enabled = !value; }
		}
	}

	public class StatusCounter
	{
		private readonly int _statusPosition;
		private readonly char[] _statusCharacters;
		private readonly string _countDisplayFormat;
		private readonly EnabledContainer _enabled;

		private readonly List<StatusCounter> _subCounters = new List<StatusCounter>();
		private readonly List<string> _files = new List<string>();

		public StatusCounter(string countDisplayFormat, EnabledContainer enabled, int statusPosition, char[] statusCharacters)
		{
			_statusPosition = statusPosition;
			_statusCharacters = statusCharacters;
			_countDisplayFormat = countDisplayFormat;
			_enabled = enabled;
		}

		public int StatusPosition
		{
			get { return _statusPosition; }
		}
		public char[] StatusCharacters
		{
			get { return _statusCharacters; }
		}
		public string CountDisplayFormat
		{
			get { return _countDisplayFormat; }
		}

		public List<StatusCounter> SubCounters
		{
			get { return _subCounters; }
		}
		public List<string> Files
		{
			get { return _files; }
		}

		public int Count
		{
			get { return Files.Count; }
		}
		public int Total
		{
			get { return Count + SubCounters.Sum(x => x.Total); }
		}

		public void AddStatusLine(string status, string file)
		{
			if (_enabled.Enabled && status.Length >= StatusPosition + 1)
			{
				char c = status[StatusPosition];
				if (StatusCharacters.Contains(c))
				{
					Files.Add(file);
				}
			}
			foreach (var sub in SubCounters)
			{
				sub.AddStatusLine(status, file);
			}
		}

		public StatusCounter ChildCounter(string countDisplayFormat, EnabledContainer enabled, int statusPosition, char statusCharacter)
		{
			return ChildCounter(countDisplayFormat, enabled, statusPosition, new[] { statusCharacter });
		}
		public StatusCounter ChildCounter(string countDisplayFormat, EnabledContainer enabled, int statusPosition, char[] statusCharacters)
		{
			_subCounters.Add(new StatusCounter(countDisplayFormat, enabled, statusPosition, statusCharacters));
			return this;
		}
		public StatusCounter ChildCounter(string countDisplayFormat, EnabledContainer enabled)
		{
			_subCounters.Add(new StatusCounter(countDisplayFormat, enabled, StatusPosition, StatusCharacters));
			return this;
		}

		public void AddSubCounterToAll(string displayFormat, EnabledContainer enabled)
		{
			foreach (var sub in _subCounters)
			{
				sub.AddSubCounterToAll(displayFormat, enabled);
			}
			ChildCounter(displayFormat, enabled);
		}

		public override string ToString()
		{
			if (Total == 0)
			{
				return "";
			}

			var result = new StringBuilder();
			result.AppendFormat(CountDisplayFormat, Count);
			foreach (var sub in SubCounters)
			{
				result.Append(sub);
			}

			return result.ToString();
		}
	}
	public class StatusCounterCollection
	{
		private readonly int _statusLength;
		private readonly List<StatusCounter> _counters = new List<StatusCounter>();

		public StatusCounterCollection(int statusLength)
		{
			_statusLength = statusLength;
		}

		public int StatusLength
		{
			get { return _statusLength; }
		}
		public List<StatusCounter> Counters
		{
			get { return _counters; }
		}

		public StatusCounter AddCounter(string countDisplayFormat, EnabledContainer enabled, int statusPosition, char statusCharacter)
		{
			return AddCounter(countDisplayFormat, enabled, statusPosition, new[] { statusCharacter });
		}
		public StatusCounter AddCounter(string countDisplayFormat, EnabledContainer enabled, int statusPosition, char[] statusCharacters)
		{
			var counter = new StatusCounter(countDisplayFormat, enabled, statusPosition, statusCharacters);
			_counters.Add(counter);
			return counter;
		}

		public override string ToString()
		{
			return string.Join(" ", _counters.Select(c => c.ToString())
				.Where(s => !string.IsNullOrEmpty(s)));
		}

		public void AddStatusLine(string line)
		{
			if (string.IsNullOrEmpty(line) || line.Length < _statusLength)
			{
				return;
			}

			string status = line.Substring(0, _statusLength);
			string file = line.Substring(_statusLength);

			foreach (var counter in Counters)
			{
				counter.AddStatusLine(status, file);
			}
		}

		public void AddSubCounterToAll(string displayFormat, EnabledContainer enabledContainer)
		{
			foreach (var counter in _counters)
			{
				counter.AddSubCounterToAll(displayFormat, enabledContainer);
			}
		}
	}
	public class SubversionStatusCounterCollection
		: StatusCounterCollection
	{
		public SubversionStatusCounterCollection(EnabledContainer onChangeLists)
			: base(8)
		{
			var mainEnabled = new ReverseEnabledContainer(onChangeLists);
			AddCounter("a:{0}", mainEnabled, 0, 'A');

			AddCounter("m:{0}", mainEnabled, 0, new[] { 'M', 'R' })
				.ChildCounter("+{0}", mainEnabled, 1, 'M');

			AddCounter("d:{0}", mainEnabled, 0, 'D')
				.ChildCounter("/{0}", mainEnabled, 0, '!');

			AddCounter("C:{0}", mainEnabled, 0, 'C')
				.ChildCounter("+{0}", mainEnabled, 1, 'C');

			AddCounter("L:{0}", mainEnabled, 3, 'L');

			AddCounter("?:{0}", mainEnabled, 0, '?');

			AddSubCounterToAll("({0})", onChangeLists);
		}
	}
'@


if (test-path function:\prompt) {
	$oldPrompt = ls function: | ? {$_.Name -eq "prompt"}
	remove-item -force function:\prompt
}
function prompt {
	[console]::TreatControlCAsInput = $true

	function outputNormal([string]$message)
	{
		Write-Host ($message) -NoNewLine -ForegroundColor Green
	}

	function outputBranch([string]$message)
	{
		Write-Host ($message) -NoNewLine -ForegroundColor Yellow
	}

	function outputMarker([string]$message)
	{
		Write-Host ($message) -NoNewLine -ForegroundColor DarkGreen
	}

	function outputImportant([string]$message)
	{
		Write-Host ($message) -NoNewLine -ForegroundColor Red
	}

	function incrementChangeList($onChangeList, [ref]$counter, [ref]$changeListCounter)
	{
		if ($onChangeList -eq $true)
		{
			$changeListCounter.value = $changeListCounter.value + 1
			outputMarker "+"
		}
		else
		{
			$counter.Value = $counter.Value + 1
			outputMarker "."
		}

		write-host "counter: $counter, change list: $changeListCounter"
	}
	function WriteSvnStatus
	{
		if (Get-Command "svn")
		{
			$info = svn info
			if ($info.Exception -ne $null)
			{
				return $false
			}
			if ($LASTEXITCODE -ne 0)
			{
				return $false
			}

			$root = ''
			$url = ''
			$url_root = ''
			$rev = 0
			$info | foreach {
				if ($_ -match "^Working Copy Root Path: (.*)$")
				{
					$root = $matches[1]
				}
				if ($_ -match "^URL: (.*)$")
				{
					$url = $matches[1]
				}
				if ($_ -match "^Repository Root: (.*)$")
				{
					$url_root = $matches[1]
				}
				if ($_ -match "^Revision: (.*)$")
				{
					$rev = $matches[1]
				}
			}

			$branch = $url.Substring($url_root.Length + 1)

			outputMarker " ("
			outputBranch $branch

			$stat = svn status $root

			$onChangeLists = New-Object EnabledContainer
			$onChangeLists.Enabled = $false

			$counters = New-Object SubversionStatusCounterCollection -ArgumentList $onChangeLists

			$stat | foreach {
				if ($_ -match "^--- Changelist")
				{
					$onChangeLists.Enabled = $true
				}
				$counters.AddStatusLine($_)
			}

			$output = $counters.ToString()
			if ($output.Length -gt 0)
			{
				outputNormal " "
				outputNormal $output
			}

			outputMarker ")"
			return $true
		}
		else
		{
			return $false
		}
	}

	function writeGitStatus {
		$branch = git branch -v -v --color=never 2>&1
		if ($branch.Exception -ne $null) {
			return $false
		}

		outputMarker " ("
		$branch | foreach {
			if ($_ -match "^\*\s*([^ ]*)\s*") {
				$branch = $matches[1].trim()
				outputBranch $branch
				if ($_ -match "ahead ([0-9]+)") {
					outputImportant ("+" + $matches[1])
				}
				if ($_ -match "behind ([0-9]+)") {
					outputImportant ("-" + $matches[1])
				}
			}
		}

		$untracked = 0
		$updates = 0
		$deletes = 0

		$addsIndex = 0
		$deletesIndex = 0
		$updatesIndex = 0
		$renamesIndex = 0

		git status --porcelain | foreach {
			if ($_ -match "^([\w?]|\s)([\w?])?\s*") {
				switch ($matches[1]) {
					"A" { $addsIndex++ }
					"M" { $updatesIndex++ }
					"D" { $deletesIndex++ }
					"R" { $renamesIndex++ }
					"?" { $untracked++ }
				}
				switch ($matches[2]) {
					"M" { $updates++ }
					"D" { $deletes++ }
				}
			}
		}

		# Treat renames as modifications
		$updatesIndex += $renamesIndex

		if ($addsIndex -gt 0) {
			outputNormal " a:$addsIndex"
		}

		if (($updates + $updatesIndex) -gt 0) {
			outputNormal " m:$updatesIndex"
			if ($updates -gt 0) {
				outputNormal "/$updates"
			}
		}

		if (($deletes + $deletesIndex) -gt 0) {
			outputNormal " d:$deletesIndex"
			if ($deletes -gt 0) {
				outputNormal "/$deletes"
			}
		}

		if ($untracked -gt 0) {
			outputNormal " ?:$untracked"
		}

		outputMarker ")"
		return $true
	}

	& $oldPrompt
	writeSvnStatus
	writeGitStatus
	[console]::TreatControlCAsInput = $false
	return "> "
}