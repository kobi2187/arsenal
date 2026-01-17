## Forensic Artifact Extraction
## ==============================
##
## Extract forensic artifacts from files, memory dumps, and disk images.
## Supports extraction of strings, timestamps, metadata, URLs, email addresses, etc.
##
## Features:
## - String extraction (ASCII, Unicode)
## - Timestamp detection (various formats)
## - Email and URL extraction
## - Registry key parsing (Windows)
## - EXIF metadata (images)
## - Network artifacts (IP addresses, MAC addresses)
##
## Usage:
## ```nim
## import arsenal/forensics/artifacts
##
## let data = readFile("memory.dump")
## let strings = extractAsciiStrings(data, minLen = 10)
## let emails = extractEmails(data)
## let ips = extractIpAddresses(data)
## ```

import std/strutils
import std/times
import std/re
import std/tables

# =============================================================================
# String Extraction
# =============================================================================

proc extractAsciiStrings*(data: openArray[uint8], minLen: int = 4): seq[string] =
  ## Extract printable ASCII strings from binary data
  ## Minimum length defaults to 4 characters
  var currentString = ""

  for i in 0..<data.len:
    let c = data[i].char

    # Printable ASCII (space to ~, plus tab and newline)
    if (c >= ' ' and c <= '~') or c == '\t' or c == '\n':
      currentString.add(c)
    else:
      if currentString.len >= minLen:
        result.add(currentString.strip())
      currentString = ""

  if currentString.len >= minLen:
    result.add(currentString.strip())

proc extractUnicodeStrings*(data: openArray[uint8], minLen: int = 4): seq[string] =
  ## Extract Unicode (UTF-16LE) strings from binary data
  var currentString = ""
  var i = 0

  while i + 1 < data.len:
    let c1 = data[i]
    let c2 = data[i + 1]

    # UTF-16LE: low byte first, high byte should be 0 for ASCII range
    if c2 == 0 and ((c1 >= 32 and c1 <= 126) or c1 == 9 or c1 == 10):
      currentString.add(c1.char)
    else:
      if currentString.len >= minLen:
        result.add(currentString.strip())
      currentString = ""

    i += 2

  if currentString.len >= minLen:
    result.add(currentString.strip())

proc extractAllStrings*(data: openArray[uint8], minLen: int = 4): seq[string] =
  ## Extract both ASCII and Unicode strings
  result = extractAsciiStrings(data, minLen)
  result.add(extractUnicodeStrings(data, minLen))

# =============================================================================
# Pattern Extraction (Email, URL, IP, etc.)
# =============================================================================

proc extractEmails*(data: openArray[uint8]): seq[string] =
  ## Extract email addresses
  let text = cast[string](data)
  let emailPattern = re"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"

  for match in findAll(text, emailPattern):
    if match notin result:
      result.add(match)

proc extractUrls*(data: openArray[uint8]): seq[string] =
  ## Extract URLs (http, https, ftp)
  let text = cast[string](data)
  let urlPattern = re"(https?|ftp)://[^\s/$.?#].[^\s]*"

  for match in findAll(text, urlPattern):
    if match notin result:
      result.add(match)

proc extractIpAddresses*(data: openArray[uint8]): seq[string] =
  ## Extract IPv4 addresses
  let text = cast[string](data)
  let ipPattern = re"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b"

  for match in findAll(text, ipPattern):
    # Validate it's a real IP (each octet <= 255)
    let octets = match.split('.')
    if octets.len == 4:
      var valid = true
      for octet in octets:
        try:
          if parseInt(octet) > 255:
            valid = false
            break
        except:
          valid = false
          break

      if valid and match notin result:
        result.add(match)

proc extractMacAddresses*(data: openArray[uint8]): seq[string] =
  ## Extract MAC addresses (various formats)
  let text = cast[string](data)
  # Matches: 00:11:22:33:44:55, 00-11-22-33-44-55, 001122334455
  let macPattern = re"(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}|[0-9A-Fa-f]{12}"

  for match in findAll(text, macPattern):
    if match notin result:
      result.add(match)

proc extractDomains*(data: openArray[uint8]): seq[string] =
  ## Extract domain names
  let text = cast[string](data)
  let domainPattern = re"(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}"

  for match in findAll(text, domainPattern):
    if match notin result and '.' in match:
      result.add(match)

# =============================================================================
# Timestamp Extraction
# =============================================================================

type
  TimestampFormat* = enum
    ## Recognized timestamp formats
    Unix              ## Unix timestamp (seconds since epoch)
    UnixMillis        ## Unix timestamp in milliseconds
    WindowsFiletime   ## Windows FILETIME (100-nanosecond intervals since 1601)
    IsoDateTime       ## ISO 8601 (YYYY-MM-DD HH:MM:SS)
    RfcDateTime       ## RFC 2822 (Day, DD Mon YYYY HH:MM:SS)

  ExtractedTimestamp* = object
    ## Extracted timestamp with metadata
    offset*: int
    format*: TimestampFormat
    value*: int64
    dateTime*: DateTime

proc extractUnixTimestamps*(data: openArray[uint8]): seq[ExtractedTimestamp] =
  ## Extract Unix timestamps (32-bit, reasonable range)
  ## Searches for values that could be Unix timestamps (year 2000-2040)
  const minTimestamp = 946684800'i64   # 2000-01-01
  const maxTimestamp = 2208988800'i64  # 2040-01-01

  var i = 0
  while i + 4 <= data.len:
    # Read as little-endian uint32
    let value = data[i].uint32 or
                (data[i + 1].uint32 shl 8) or
                (data[i + 2].uint32 shl 16) or
                (data[i + 3].uint32 shl 24)

    if value.int64 >= minTimestamp and value.int64 <= maxTimestamp:
      try:
        let dt = fromUnix(value.int64)
        result.add(ExtractedTimestamp(
          offset: i,
          format: Unix,
          value: value.int64,
          dateTime: dt
        ))
      except:
        discard

    i += 1

proc extractWindowsFiletimes*(data: openArray[uint8]): seq[ExtractedTimestamp] =
  ## Extract Windows FILETIME timestamps (64-bit)
  ## FILETIME = 100-nanosecond intervals since Jan 1, 1601
  const fileTimeEpoch = 116444736000000000'i64  # Diff between 1601 and 1970

  var i = 0
  while i + 8 <= data.len:
    # Read as little-endian uint64
    let value = data[i].uint64 or
                (data[i + 1].uint64 shl 8) or
                (data[i + 2].uint64 shl 16) or
                (data[i + 3].uint64 shl 24) or
                (data[i + 4].uint64 shl 32) or
                (data[i + 5].uint64 shl 40) or
                (data[i + 6].uint64 shl 48) or
                (data[i + 7].uint64 shl 56)

    # Convert to Unix timestamp
    if value > fileTimeEpoch:
      let unixTime = (value.int64 - fileTimeEpoch) div 10_000_000

      # Reasonable range check
      if unixTime >= 946684800'i64 and unixTime <= 2208988800'i64:
        try:
          let dt = fromUnix(unixTime)
          result.add(ExtractedTimestamp(
            offset: i,
            format: WindowsFiletime,
            value: value.int64,
            dateTime: dt
          ))
        except:
          discard

    i += 1

# =============================================================================
# Windows Registry Artifacts
# =============================================================================

type
  RegistryKey* = object
    ## Extracted registry key
    path*: string
    name*: string
    value*: string
    dataType*: string

proc extractRegistryPaths*(data: openArray[uint8]): seq[string] =
  ## Extract Windows registry paths from strings
  let strings = extractUnicodeStrings(data, minLen = 10)
  let regPattern = re"(?i)HKEY_[A-Z_]+\\[^\\]+(\\[^\\]+)*"

  for str in strings:
    for match in findAll(str, regPattern):
      if match notin result:
        result.add(match)

# =============================================================================
# File Metadata Extraction
# =============================================================================

type
  FileMetadata* = object
    ## Common file metadata
    filename*: string
    size*: int64
    created*: Option[DateTime]
    modified*: Option[DateTime]
    accessed*: Option[DateTime]
    attributes*: seq[string]

proc extractFilenames*(data: openArray[uint8]): seq[string] =
  ## Extract potential filenames (with extensions)
  let strings = extractAllStrings(data, minLen = 4)
  let filenamePattern = re"[a-zA-Z0-9_\-]+\.[a-zA-Z0-9]{2,4}"

  for str in strings:
    for match in findAll(str, filenamePattern):
      if match notin result:
        result.add(match)

proc extractPaths*(data: openArray[uint8]): seq[string] =
  ## Extract file paths (Windows and Unix)
  let strings = extractAllStrings(data, minLen = 8)

  # Windows paths: C:\path\to\file
  let winPathPattern = re"[A-Za-z]:\\(?:[^\\/:*?\"<>|\r\n]+\\)*[^\\/:*?\"<>|\r\n]*"

  # Unix paths: /path/to/file
  let unixPathPattern = re"/(?:[^/\0\n]+/)*[^/\0\n]+"

  for str in strings:
    for match in findAll(str, winPathPattern):
      if match notin result:
        result.add(match)

    for match in findAll(str, unixPathPattern):
      if match.len > 3 and match notin result:  # Avoid single "/"
        result.add(match)

# =============================================================================
# Network Artifacts
# =============================================================================

type
  NetworkArtifact* = object
    ## Network-related artifact
    artifactType*: string  # "IP", "MAC", "URL", "Domain", "Email"
    value*: string
    offset*: int

proc extractNetworkArtifacts*(data: openArray[uint8]): seq[NetworkArtifact] =
  ## Extract all network-related artifacts
  # IP addresses
  for ip in extractIpAddresses(data):
    result.add(NetworkArtifact(artifactType: "IP", value: ip, offset: 0))

  # MAC addresses
  for mac in extractMacAddresses(data):
    result.add(NetworkArtifact(artifactType: "MAC", value: mac, offset: 0))

  # URLs
  for url in extractUrls(data):
    result.add(NetworkArtifact(artifactType: "URL", value: url, offset: 0))

  # Domains
  for domain in extractDomains(data):
    result.add(NetworkArtifact(artifactType: "Domain", value: domain, offset: 0))

  # Emails
  for email in extractEmails(data):
    result.add(NetworkArtifact(artifactType: "Email", value: email, offset: 0))

# =============================================================================
# Credential Extraction
# =============================================================================

proc extractPotentialCredentials*(data: openArray[uint8]): seq[tuple[key: string, value: string]] =
  ## Extract potential credentials (username/password patterns)
  let strings = extractAllStrings(data, minLen = 5)

  # Look for common patterns
  let patterns = [
    (re"(?i)(username|user|login)[:\s=]+([^\s\n]+)", "Username"),
    (re"(?i)(password|passwd|pwd)[:\s=]+([^\s\n]+)", "Password"),
    (re"(?i)(token|api[_-]?key)[:\s=]+([^\s\n]+)", "Token"),
    (re"(?i)(secret)[:\s=]+([^\s\n]+)", "Secret")
  ]

  for str in strings:
    for (pattern, credType) in patterns:
      for match in findAll(str, pattern):
        result.add((credType, match))

# =============================================================================
# Report Generation
# =============================================================================

type
  ArtifactReport* = object
    ## Comprehensive artifact report
    strings*: seq[string]
    emails*: seq[string]
    urls*: seq[string]
    ips*: seq[string]
    timestamps*: seq[ExtractedTimestamp]
    filenames*: seq[string]
    paths*: seq[string]
    networkArtifacts*: seq[NetworkArtifact]

proc generateReport*(data: openArray[uint8]): ArtifactReport =
  ## Generate comprehensive artifact report
  result.strings = extractAsciiStrings(data, minLen = 8)
  result.emails = extractEmails(data)
  result.urls = extractUrls(data)
  result.ips = extractIpAddresses(data)
  result.timestamps = extractUnixTimestamps(data)
  result.filenames = extractFilenames(data)
  result.paths = extractPaths(data)
  result.networkArtifacts = extractNetworkArtifacts(data)

proc `$`*(report: ArtifactReport): string =
  result = "Forensic Artifact Report\n"
  result.add("=" .repeat(60) & "\n\n")

  result.add("Strings: " & $report.strings.len & "\n")
  result.add("Emails: " & $report.emails.len & "\n")
  result.add("URLs: " & $report.urls.len & "\n")
  result.add("IP Addresses: " & $report.ips.len & "\n")
  result.add("Timestamps: " & $report.timestamps.len & "\n")
  result.add("Filenames: " & $report.filenames.len & "\n")
  result.add("Paths: " & $report.paths.len & "\n")
  result.add("Network Artifacts: " & $report.networkArtifacts.len & "\n")

proc saveReport*(report: ArtifactReport, filename: string) =
  ## Save report to file
  writeFile(filename, $report)
